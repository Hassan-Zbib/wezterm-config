local wezterm = require('wezterm')
local act = wezterm.action

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


---Build a layout tree from panes_with_info position data.
---Stores split ratios for exact pane proportions on restore.
---@param panes table[] list of {left, top, width, height, cwd}
---@return table layout tree node
local function build_layout(panes)
   if #panes == 1 then
      local p = panes[1]
      return {
         type = 'leaf',
         cwd = p.cwd,
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
      },
      right = build_layout(panes),
   }
end


---Restore a layout tree into a pane by recursively splitting.
---Collects all leaf panes with their target CWDs.
---@param pane table WezTerm Pane
---@param node table layout tree node
---@param leaves table[] accumulator for {pane, cwd}
local function restore_layout(pane, node, leaves)
   if node.type == 'leaf' then
      table.insert(leaves, { pane = pane, cwd = node.cwd })
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

   local tabs = {}
   for _, tab in ipairs(all_tabs) do
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

   local target_workspace = session.workspace or 'default'
   local _tab, first_pane, mux_win = wezterm.mux.spawn_window({
      workspace = target_workspace,
   })

   for tab_idx, tab in ipairs(session.tabs) do
      local tab_pane

      if tab_idx == 1 then
         tab_pane = first_pane
      else
         local _, new_pane, _ = mux_win:spawn_tab({})
         tab_pane = new_pane
      end

      local leaves = {}
      restore_layout(tab_pane, tab.layout, leaves)

      for _, leaf in ipairs(leaves) do
         if leaf.cwd then
            leaf.pane:send_text("cd '" .. leaf.cwd:gsub("'", "'\\''") .. "' && clear\n")
         end
      end
   end

   window:perform_action(act.SwitchToWorkspace({ name = target_workspace }), pane)
   window:toast_notification(
      'Session Restored',
      'Restored "' .. name .. '" (' .. #session.tabs .. ' tabs) in workspace "' .. target_workspace .. '"',
      nil,
      3000
   )
end

return M
