local wezterm = require('wezterm')
local act = wezterm.action

local M = {}

local sessions_file = wezterm.config_dir .. '/sessions.json'

-- ── Process restore config ──────────────────────────────────────────
-- Maps process basename (lowercase, no .exe) to its launch command.
-- "shells" are sub-shells where cd happens INSIDE them after launch.
-- "tuis" are TUI apps where cd happens in bash BEFORE launching.
-- stylua: ignore
M.shells = {
   pwsh       = 'pwsh',
   powershell = 'powershell',
   wsl        = 'wsl',
   python     = 'python',
   python3    = 'python3',
   node       = 'node',
   lua        = 'lua',
}

-- stylua: ignore
M.tuis = {
   yazi       = 'yazi',
   lazygit    = 'lazygit',
   btop       = 'btop',
   btop4win   = 'btop',
   glow       = 'glow',
   claude     = 'claude',
   vim        = 'vim',
   nvim       = 'nvim',
   nano       = 'nano',
   htop       = 'htop',
   lnav       = 'lnav',
}

---Read sessions from disk
---@return table<string, table>
local function read_sessions()
   local file = io.open(sessions_file, 'r')
   if not file then
      return {}
   end
   local content = file:read('*a')
   file:close()
   if content == '' then
      return {}
   end
   local ok, data = pcall(wezterm.json_parse, content)
   if not ok then
      return {}
   end
   return data
end

---Write sessions to disk
---@param sessions table<string, table>
local function write_sessions(sessions)
   local json = wezterm.json_encode(sessions)
   local file = io.open(sessions_file, 'w')
   if not file then
      wezterm.log_error('Failed to write sessions file: ' .. sessions_file)
      return false
   end
   file:write(json)
   file:close()
   return true
end

---Compute total width/height of a group of panes
---@param panes table[]
---@return number, number total_width, total_height
local function group_dimensions(panes)
   local min_left, min_top = math.huge, math.huge
   local max_right, max_bottom = 0, 0
   for _, p in ipairs(panes) do
      if p.left < min_left then min_left = p.left end
      if p.top < min_top then min_top = p.top end
      local right = p.left + p.width
      local bottom = p.top + p.height
      if right > max_right then max_right = right end
      if bottom > max_bottom then max_bottom = bottom end
   end
   return max_right - min_left, max_bottom - min_top
end

---Extract the last command typed in a pane via OSC 133 semantic zones
---@param pane_obj table WezTerm Pane
---@return string|nil
local function last_command(pane_obj)
   local ok, zones = pcall(pane_obj.get_semantic_zones, pane_obj)
   if not ok or not zones then
      return nil
   end

   for i = #zones, 1, -1 do
      if zones[i].semantic_type == 'Input' then
         local z = zones[i]
         local ok2, text =
            pcall(pane_obj.get_lines_as_text, pane_obj, z.start_y, z.end_y)
         if not ok2 or not text then
            return nil
         end
         -- The full line includes the prompt; trim to the input column range
         local lines = {}
         for line in (text .. '\n'):gmatch('(.-)\n') do
            table.insert(lines, line)
         end
         if #lines == 0 then
            return nil
         end
         lines[1] = lines[1]:sub(z.start_x + 1)
         local cmd = table.concat(lines, '\n'):gsub('^%s+', ''):gsub('%s+$', '')
         return cmd ~= '' and cmd or nil
      end
   end
   return nil
end

---Extract basename, strip .exe, lowercase
---@param path string
---@return string
local function proc_basename(path)
   local base = path:match('[/\\]([^/\\]+)$') or path
   return base:gsub('%.exe$', ''):lower()
end

---Classify a single process name/path as shell, tui, or nil.
---Also detects WSL by checking for Linux-style paths.
---@param name string full process name/path
---@return string|nil kind
---@return string|nil command
local function classify_process(name)
   local base = proc_basename(name)
   if M.shells[base] then
      return 'shell', M.shells[base]
   end
   if M.tuis[base] then
      return 'tui', M.tuis[base]
   end
   -- Heuristic: Linux-style path (e.g. /usr/bin/bash inside WSL)
   -- but not Git Bash's /c/Users/... MSYS paths
   if name:match('^/') and not name:match('^/[a-zA-Z]/') then
      return 'shell', 'wsl'
   end
   return nil, nil
end

---Build a PID → {name, ppid} lookup table from Windows process list.
---@return table<number, {name: string, ppid: number}>|nil
local function build_process_table()
   -- wmic sorts columns alphabetically: Name, ParentProcessId, ProcessId
   local handle = io.popen('wmic process get Name,ProcessId,ParentProcessId /format:csv 2>NUL')
   if not handle then
      return nil
   end
   local output = handle:read('*a')
   handle:close()

   local procs = {}
   for line in output:gmatch('[^\r\n]+') do
      local pname, ppid, pid = line:match(',([^,]+),(%d+),(%d+)')
      if pname and ppid and pid then
         procs[tonumber(pid)] = {
            name = proc_basename(pname),
            ppid = tonumber(ppid),
         }
      end
   end
   return next(procs) and procs or nil
end

---Walk up the process tree from a given PID to find parent shells.
---@param procs table process lookup table
---@param start_ppid number parent PID to start walking from
---@return table[] list of {kind, cmd} for shells found
local function find_parent_shells(procs, start_ppid)
   local shells = {}
   local seen_cmds = {}
   local pid = start_ppid
   local visited = {}
   while pid and procs[pid] and not visited[pid] do
      visited[pid] = true
      local info = procs[pid]
      if M.shells[info.name] then
         local cmd = M.shells[info.name]
         -- Avoid duplicates (e.g. wsl spawns multiple wsl.exe processes)
         if not seen_cmds[cmd] then
            seen_cmds[cmd] = true
            table.insert(shells, 1, { kind = 'shell', cmd = cmd })
         end
      elseif info.name == 'bash' or info.name == 'sh' then
         break -- reached the root Git Bash shell
      end
      pid = info.ppid
   end
   return shells
end

---Build the process chain for a pane by walking the Windows process tree.
---Returns a list like: { {kind='shell', cmd='pwsh'}, {kind='tui', cmd='claude'} }
---@param pane_obj table WezTerm Pane
---@param procs table|nil pre-built process table (optional, avoids re-running wmic)
---@return table[] chain
local function detect_process_chain(pane_obj, procs)
   local ok, fg_name = pcall(pane_obj.get_foreground_process_name, pane_obj)
   if not ok or not fg_name then
      return {}
   end

   local fg_kind, fg_cmd = classify_process(fg_name)
   local fg_base = proc_basename(fg_name)

   -- Always try to walk the process tree to find parent shells
   if not procs then
      procs = build_process_table()
   end

   local parent_shells = {}
   if procs then
      -- Find PIDs matching the foreground process and check their ancestry
      for pid, info in pairs(procs) do
         if info.name == fg_base then
            local shells = find_parent_shells(procs, info.ppid)
            if #shells > 0 then
               parent_shells = shells
               break
            end
         end
      end
   end

   -- Build the final chain
   local chain = {}
   for _, s in ipairs(parent_shells) do
      table.insert(chain, s)
   end

   if fg_kind == 'shell' then
      -- Only add if not already found as a parent (avoid duplicates like wsl→wsl)
      local dominated = false
      for _, s in ipairs(parent_shells) do
         if s.cmd == fg_cmd then
            dominated = true
            break
         end
      end
      if not dominated then
         table.insert(chain, { kind = 'shell', cmd = fg_cmd })
      end
   elseif fg_kind == 'tui' then
      table.insert(chain, { kind = 'tui', cmd = fg_cmd })
   end

   return chain
end

---Build a layout tree from panes_with_info position data.
---Stores split ratios for exact pane proportions on restore.
---@param panes table[] list of {left, top, width, height, cwd, cmd, process_chain}
---@return table layout tree node
local function build_layout(panes)
   if #panes == 1 then
      local p = panes[1]
      return {
         type = 'leaf',
         cwd = p.cwd,
         cmd = p.cmd,
         process_chain = p.process_chain,
      }
   end

   -- Try vertical split (left/right groups)
   table.sort(panes, function(a, b) return a.left < b.left end)
   local min_left = panes[1].left
   local left_group, right_group = {}, {}
   for _, p in ipairs(panes) do
      if p.left == min_left then
         table.insert(left_group, p)
      else
         table.insert(right_group, p)
      end
   end
   if #left_group > 0 and #right_group > 0 then
      local total_w = group_dimensions(panes)
      local left_w = group_dimensions(left_group)
      local size = math.floor((left_w / total_w) * 100 + 0.5)
      return {
         type = 'split',
         direction = 'Right',
         size = size,
         left = build_layout(left_group),
         right = build_layout(right_group),
      }
   end

   -- Try horizontal split (top/bottom groups)
   table.sort(panes, function(a, b) return a.top < b.top end)
   local min_top = panes[1].top
   local top_group, bottom_group = {}, {}
   for _, p in ipairs(panes) do
      if p.top == min_top then
         table.insert(top_group, p)
      else
         table.insert(bottom_group, p)
      end
   end
   if #top_group > 0 and #bottom_group > 0 then
      local _, total_h = group_dimensions(panes)
      local _, top_h = group_dimensions(top_group)
      local size = math.floor((top_h / total_h) * 100 + 0.5)
      return {
         type = 'split',
         direction = 'Bottom',
         size = size,
         left = build_layout(top_group),
         right = build_layout(bottom_group),
      }
   end

   -- Fallback
   local first = table.remove(panes, 1)
   return {
      type = 'split',
      direction = 'Right',
      size = 50,
      left = {
         type = 'leaf',
         cwd = first.cwd,
         cmd = first.cmd,
         process_chain = first.process_chain,
      },
      right = build_layout(panes),
   }
end

---Get the cwd of the first (top-left) leaf in a layout tree
---@param node table layout tree node
---@return string|nil
local function first_cwd(node)
   if node.type == 'leaf' then
      return node.cwd
   end
   return first_cwd(node.left)
end

---Restore a layout tree into a pane by recursively splitting.
---Collects all leaf panes with their target CWDs so callers can cd into them.
---@param pane table WezTerm Pane
---@param node table layout tree node
---@param leaves table[] accumulator for {pane, cwd} pairs
local function restore_layout(pane, node, leaves)
   if node.type == 'leaf' then
      table.insert(leaves, {
         pane = pane,
         cwd = node.cwd,
         cmd = node.cmd,
         process_chain = node.process_chain,
      })
      return
   end

   -- The saved size is the left/top portion percentage.
   -- split() takes the size of the NEW pane (right/bottom) as a 0-1 fraction.
   local right_frac = (100 - (node.size or 50)) / 100

   local new_pane = pane:split({
      direction = node.direction,
      size = right_frac,
   })

   restore_layout(pane, node.left, leaves)
   restore_layout(new_pane, node.right, leaves)
end

---Save the current session with a descriptive name
---@param window table WezTerm Window
---@param pane table WezTerm Pane
---@param name? string optional custom name (auto-generates if nil)
function M.save(window, pane, name)
   local workspace = window:active_workspace()
   local mux_window = window:mux_window()
   local all_tabs = mux_window:tabs()
   local active_tab = window:active_tab()
   local tab_title = active_tab:get_title() or 'tab'

   -- Auto-generate name: workspace-tab-datetime
   if not name then
      local datetime = os.date('%Y%m%d-%H%M%S')
      name = workspace .. '-' .. tab_title .. '-' .. datetime
      -- Sanitize: remove special chars that could break keys
      name = name:gsub('[^%w%-_%.%s]', ''):gsub('%s+', '-')
   end

   -- Build the Windows process table once for all panes
   local procs = build_process_table()

   local tabs = {}
   for _, tab in ipairs(all_tabs) do
      local panes_info = {}
      for _, info in ipairs(tab:panes_with_info()) do
         local cwd = info.pane:get_current_working_dir()
         local chain = detect_process_chain(info.pane, procs)
         table.insert(panes_info, {
            left = info.left,
            top = info.top,
            width = info.width,
            height = info.height,
            cwd = cwd and (cwd.file_path or tostring(cwd)) or nil,
            cmd = last_command(info.pane),
            process_chain = #chain > 0 and chain or nil,
         })
      end
      if #panes_info > 0 then
         table.insert(tabs, { layout = build_layout(panes_info) })
      end
   end

   local sessions = read_sessions()
   sessions[name] = {
      workspace = workspace,
      tabs = tabs,
      saved_at = os.date('%Y-%m-%d %H:%M:%S'),
   }

   if write_sessions(sessions) then
      window:toast_notification(
         'Session Saved',
         'Saved "' .. name .. '" (' .. #tabs .. ' tabs)',
         nil,
         3000
      )
   end
end

---Save with a custom name via prompt
---@param window table WezTerm Window
---@param pane table WezTerm Pane
function M.save_with_name(window, pane)
   window:perform_action(
      act.PromptInputLine({
         description = 'Session name (leave empty for auto):',
         action = wezterm.action_callback(function(win, p, line)
            if line == nil then
               return -- cancelled
            end
            local name = line ~= '' and line or nil
            M.save(win, p, name)
         end),
      }),
      pane
   )
end

---Build InputSelector choices from saved sessions
---@return table[]
function M.choices()
   local sessions = read_sessions()
   local choices = {}
   for name, session in pairs(sessions) do
      local tab_count = #session.tabs
      local label = name .. '  (' .. tab_count .. ' tabs, saved ' .. (session.saved_at or '?') .. ')'
      table.insert(choices, { id = name, label = label })
   end
   table.sort(choices, function(a, b) return a.id < b.id end)
   return choices
end

---Delete a saved session by name
---@param window table WezTerm Window
---@param pane table WezTerm Pane
function M.delete(window, pane)
   window:perform_action(act.InputSelector({
      title = 'Delete Session',
      choices = M.choices(),
      fuzzy = true,
      fuzzy_description = 'Select Session to Delete: ',
      action = wezterm.action_callback(function(win, _p, id)
         if not id then
            return
         end
         local sessions = read_sessions()
         sessions[id] = nil
         if write_sessions(sessions) then
            win:toast_notification('Session Deleted', 'Deleted "' .. id .. '"', nil, 3000)
         end
      end),
   }), pane)
end

---Restore a saved session by name
---@param window table WezTerm Window
---@param pane table WezTerm Pane
---@param name string session name
function M.restore(window, pane, name)
   local sessions = read_sessions()
   local session = sessions[name]
   if not session then
      window:toast_notification('Session Restore', 'Session "' .. name .. '" not found', nil, 3000)
      return
   end

   for tab_idx, tab in ipairs(session.tabs) do
      local tab_pane

      if tab_idx == 1 then
         tab_pane = pane
      else
         local _, new_pane, _ = window:mux_window():spawn_tab({})
         tab_pane = new_pane
      end

      local leaves = {}
      restore_layout(tab_pane, tab.layout, leaves)

      for _, leaf in ipairs(leaves) do
         local chain = leaf.process_chain or {}

         -- Separate shells (launched first) from TUI (launched last)
         local shells = {}
         local tui = nil
         for _, entry in ipairs(chain) do
            if entry.kind == 'shell' then
               table.insert(shells, entry.cmd)
            elseif entry.kind == 'tui' then
               tui = entry.cmd
            end
         end

         -- Build a cd command appropriate for the innermost shell
         local inner_shell = shells[#shells]
         local cd_text = nil
         if leaf.cwd and inner_shell then
            if inner_shell == 'pwsh' or inner_shell == 'powershell' then
               local win_path = leaf.cwd
                  :gsub('^/(%a)/', function(d) return d:upper() .. ':\\' end)
                  :gsub('/', '\\')
               cd_text = "Set-Location '" .. win_path .. "'; Clear-Host\n"
            elseif inner_shell == 'wsl' then
               -- Skip cd if the path is a stale MSYS /c/... from bash
               if not leaf.cwd:match('^/[a-zA-Z]/') then
                  cd_text = "cd '" .. leaf.cwd .. "' && clear\n"
               else
                  cd_text = 'clear\n'
               end
            else
               cd_text = "cd '" .. leaf.cwd:gsub("'", "'\\''") .. "' && clear\n"
            end
         elseif leaf.cwd then
            cd_text = "cd '" .. leaf.cwd:gsub("'", "'\\''") .. "' && clear\n"
         end

         if #shells > 0 then
            local p = leaf.pane
            -- Send Enter first to flush readline init (newly split panes
            -- can eat the first character if we type too early).
            p:send_text('\n')

            if inner_shell == 'pwsh' or inner_shell == 'powershell' then
               -- Build a single pwsh launch command with -NoExit -Command
               -- to avoid timing issues with pwsh startup.
               local ps_parts = {}
               if leaf.cwd then
                  local win_path = leaf.cwd
                     :gsub('^/(%a)/', function(d) return d:upper() .. ':\\' end)
                     :gsub('/', '\\')
                  table.insert(ps_parts, "Set-Location '" .. win_path .. "'")
                  table.insert(ps_parts, 'Clear-Host')
               end
               if tui then
                  table.insert(ps_parts, tui)
               end
               wezterm.time.call_after(2, function()
                  if #ps_parts > 0 then
                     local cmd_str = table.concat(ps_parts, '; ')
                     p:send_text(
                        inner_shell
                           .. ' -NoExit -Command "'
                           .. cmd_str
                           .. '"\n'
                     )
                  else
                     p:send_text(inner_shell .. '\n')
                  end
                  if leaf.cmd and not tui then
                     p:send_text(leaf.cmd)
                  end
               end)
            elseif inner_shell == 'wsl' then
               wezterm.time.call_after(2, function()
                  p:send_text('wsl\n')
               end)
            else
               -- Other shells (python, node, lua): just launch
               wezterm.time.call_after(2, function()
                  p:send_text(inner_shell .. '\n')
               end)
            end
         else
            -- No sub-shells: send immediately (bash is already running)
            if cd_text then
               leaf.pane:send_text(cd_text)
            end
            if tui then
               leaf.pane:send_text(tui .. '\n')
            end
            if leaf.cmd and not tui then
               leaf.pane:send_text(leaf.cmd)
            end
         end
      end
   end

   window:toast_notification(
      'Session Restored',
      'Restored "' .. name .. '" (' .. #session.tabs .. ' tabs)',
      nil,
      3000
   )
end

return M
