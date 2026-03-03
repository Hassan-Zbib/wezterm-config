local wezterm = require('wezterm')

local M = {}

local sessions_file = wezterm.config_dir .. '/sessions.json'

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

---Build a layout tree from panes_with_info position data.
---Recursively splits the pane list by finding vertical or horizontal divisions.
---@param panes table[] list of {left, top, width, height, cwd}
---@return table layout tree node
local function build_layout(panes)
   if #panes == 1 then
      return { type = 'leaf', cwd = panes[1].cwd }
   end

   -- Try vertical split (left/right groups sharing the same left edge vs further right)
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
      return {
         type = 'split',
         direction = 'Right',
         left = build_layout(left_group),
         right = build_layout(right_group),
      }
   end

   -- Try horizontal split (top/bottom groups sharing the same top edge vs further down)
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
      return {
         type = 'split',
         direction = 'Bottom',
         left = build_layout(top_group),
         right = build_layout(bottom_group),
      }
   end

   -- Fallback: shouldn't happen, but treat remaining as vertical splits
   local first = table.remove(panes, 1)
   return {
      type = 'split',
      direction = 'Right',
      left = { type = 'leaf', cwd = first.cwd },
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

---Restore a layout tree into a pane by recursively splitting
---@param pane table WezTerm Pane
---@param node table layout tree node
local function restore_layout(pane, node)
   if node.type == 'leaf' then
      return
   end

   local new_pane = pane:split({
      direction = node.direction,
      cwd = first_cwd(node.right),
   })

   restore_layout(pane, node.left)
   restore_layout(new_pane, node.right)
end

---Save the current session (all tabs and their pane layout trees)
---@param window table WezTerm Window
---@param pane table WezTerm Pane
function M.save(window, pane)
   local workspace = window:active_workspace()
   local mux_window = window:mux_window()
   local tabs = {}

   for _, tab in ipairs(mux_window:tabs()) do
      local panes_info = {}
      for _, info in ipairs(tab:panes_with_info()) do
         local cwd = info.pane:get_current_working_dir()
         table.insert(panes_info, {
            left = info.left,
            top = info.top,
            width = info.width,
            height = info.height,
            cwd = cwd and (cwd.file_path or tostring(cwd)) or nil,
         })
      end
      if #panes_info > 0 then
         table.insert(tabs, { layout = build_layout(panes_info) })
      end
   end

   local sessions = read_sessions()
   sessions[workspace] = {
      workspace = workspace,
      tabs = tabs,
      saved_at = os.date('%Y-%m-%d %H:%M:%S'),
   }

   if write_sessions(sessions) then
      window:toast_notification('Session Saved', 'Saved "' .. workspace .. '" (' .. #tabs .. ' tabs)', nil, 3000)
   end
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
      local root_cwd = first_cwd(tab.layout)
      local tab_pane

      if tab_idx == 1 then
         tab_pane = pane
         if root_cwd then
            pane:send_text('cd ' .. wezterm.shell_quote_arg(root_cwd) .. ' && clear\n')
         end
      else
         local spawn_args = {}
         if root_cwd then
            spawn_args.cwd = root_cwd
         end
         local _, new_pane, _ = window:mux_window():spawn_tab(spawn_args)
         tab_pane = new_pane
      end

      restore_layout(tab_pane, tab.layout)
   end

   window:toast_notification('Session Restored', 'Restored "' .. name .. '" (' .. #session.tabs .. ' tabs)', nil, 3000)
end

return M
