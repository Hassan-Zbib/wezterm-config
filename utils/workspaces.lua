---Workspaces & Sessions hub.
---
---A workspace is live state owned by the mux server; a session is a saved
---snapshot of one. They are the same concept at two lifetimes, so they get one
---menu rather than the five separate keybindings this replaces
---(F5 / Shift+F5 / Ctrl+F5 for workspaces, F10 for sessions).
---
---F9 still quick-saves without opening anything, because that is the one action
---frequent enough to deserve its own key.
local wezterm = require('wezterm')
local act = wezterm.action
local Cells = require('utils.cells')
local p = require('colors.palette')
local sessions = require('utils.sessions')

local M = {}

---@type table<string, Cells.SegmentColors>
local colors = {
   workspace = { fg = p.lavender },
   session = { fg = p.text },
   danger = { fg = p.red },
   hint = { fg = p.overlay1 },
}

---Build one formatted InputSelector label.
---@param text string
---@param color Cells.SegmentColors
---@param hint? string
---@return string
local function label(text, color, hint)
   local cells = Cells:new()
   cells:add_segment('main', ' ' .. text, color, { Cells.attr.intensity('Bold') })

   local ids = { 'main' }
   if hint and hint ~= '' then
      cells:add_segment('hint', '  ' .. hint, colors.hint, { Cells.attr.intensity('Half') })
      table.insert(ids, 'hint')
   end

   return wezterm.format(cells:render(ids))
end

---@param window table WezTerm Window
---@param pane table WezTerm Pane
function M.new_workspace(window, pane)
   window:perform_action(
      act.PromptInputLine({
         description = 'New workspace name:',
         action = wezterm.action_callback(function(win, p_, line)
            if line and line ~= '' then
               win:perform_action(act.SwitchToWorkspace({ name = line }), p_)
            end
         end),
      }),
      pane
   )
end

---@param window table WezTerm Window
---@param pane table WezTerm Pane
function M.rename_workspace(window, pane)
   local current = window:active_workspace()
   window:perform_action(
      act.PromptInputLine({
         description = 'Rename workspace "' .. current .. '" to:',
         action = wezterm.action_callback(function(win, p_, line)
            if line and line ~= '' then
               wezterm.mux.rename_workspace(current, line)
               -- The workspace name is rendered in the right status bar, which
               -- only redraws on this event.
               wezterm.emit('update-status', win, p_)
            end
         end),
      }),
      pane
   )
end

---Open the hub.
---@param window table WezTerm Window
---@param pane table WezTerm Pane
function M.hub(window, pane)
   local workspace = window:active_workspace()
   local attached = sessions.attached_name(workspace)

   local save_hint = attached and ('update "' .. attached .. '"') or 'names it first'

   window:perform_action(
      act.InputSelector({
         title = 'Workspaces & Sessions — "' .. workspace .. '"',
         fuzzy = true,
         fuzzy_description = 'Action: ',
         choices = {
            { id = 'switch', label = label('Switch workspace', colors.workspace, 'fuzzy picker') },
            { id = 'new_ws', label = label('New workspace', colors.workspace, 'prompts for a name') },
            { id = 'rename_ws', label = label('Rename workspace', colors.workspace, 'renames "' .. workspace .. '"') },
            { id = 'restore', label = label('Restore session', colors.session, 'into its own workspace') },
            { id = 'restore_as', label = label('Restore session as', colors.session, 'into another workspace') },
            { id = 'save', label = label('Save session', colors.session, save_hint) },
            { id = 'save_as', label = label('Save session as', colors.session, 'fork under a new name') },
            { id = 'rename_session', label = label('Rename session', colors.session) },
            { id = 'delete_session', label = label('Delete session', colors.danger, 'confirms first') },
            { id = 'folder', label = label('Open sessions folder', colors.session) },
         },
         action = wezterm.action_callback(function(win, p_, id)
            if id == 'switch' then
               win:perform_action(act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }), p_)
            elseif id == 'new_ws' then
               M.new_workspace(win, p_)
            elseif id == 'rename_ws' then
               M.rename_workspace(win, p_)
            elseif id == 'restore' then
               sessions.restore_picker(win, p_)
            elseif id == 'restore_as' then
               sessions.restore_as(win, p_)
            elseif id == 'save' then
               sessions.save(win, p_)
            elseif id == 'save_as' then
               sessions.save_as(win, p_)
            elseif id == 'rename_session' then
               sessions.rename(win, p_)
            elseif id == 'delete_session' then
               sessions.delete(win, p_)
            elseif id == 'folder' then
               sessions.open_folder()
            end
         end),
      }),
      pane
   )
end

return M
