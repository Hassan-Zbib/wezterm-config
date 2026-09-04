local wezterm = require('wezterm')
local platform = require('utils.platform')
local Cells = require('utils.cells')
local p = require('colors.palette')

local act = wezterm.action

local M = {}

---Name of the persistent unix domain declared in config/domains.lua
local MUX_DOMAIN = 'mux'

local SPAWN_PREFIX = 'spawn:'

---Domains WezTerm creates for its own internal overlays -- the debug overlay,
---InputSelector rendering, and friends. They are genuine MuxDomains and report
---as Attached, so they show up in `all_domains()` alongside the real ones, but
---opening a shell in one is meaningless. Keep them out of the menu.
local INTERNAL_DOMAINS = {
   TermWizTerminalDomain = true,
}

---@type table<string, Cells.SegmentColors>
local colors = {
   name = { fg = p.text },
   attached = { fg = p.green },
   detached = { fg = p.overlay0 },
   action = { fg = p.peach },
   danger = { fg = p.red },
}

---Read a domain's attach state without exploding on older WezTerm builds
---@param domain table MuxDomain
---@return string 'Attached'|'Detached'|''
local function domain_state(domain)
   local ok, state = pcall(function()
      return domain:state()
   end)
   if not ok or type(state) ~= 'string' then
      return ''
   end
   return state
end

---Build a single formatted InputSelector label
---@param text string
---@param color Cells.SegmentColors
---@param detail? string
---@param detail_color? Cells.SegmentColors
---@return string
local function label(text, color, detail, detail_color)
   local cells = Cells:new()
   cells:add_segment('main', ' ' .. text, color, { Cells.attr.intensity('Bold') })

   local ids = { 'main' }
   if detail and detail ~= '' then
      cells:add_segment('detail', '  ' .. detail, detail_color, { Cells.attr.intensity('Half') })
      table.insert(ids, 'detail')
   end

   return wezterm.format(cells:render(ids))
end

---Build InputSelector choices: every spawnable domain, then the mux actions
---@return table[]
function M.choices()
   local choices = {}

   for _, domain in ipairs(wezterm.mux.all_domains()) do
      local name = domain:name()
      if not INTERNAL_DOMAINS[name] then
         local state = domain_state(domain)
         table.insert(choices, {
            id = SPAWN_PREFIX .. name,
            label = label(
               name,
               colors.name,
               state,
               state == 'Attached' and colors.attached or colors.detached
            ),
         })
      end
   end

   table.sort(choices, function(a, b)
      return a.id < b.id
   end)

   table.insert(choices, {
      id = 'attach-mux',
      label = label('Attach "' .. MUX_DOMAIN .. '"', colors.action, 'reconnect the persistent mux'),
   })
   table.insert(choices, {
      id = 'detach',
      label = label('Detach current domain', colors.action, 'panes keep running'),
   })
   table.insert(choices, {
      id = 'restart',
      label = label('Restart mux server', colors.danger, 'KILLS every pane in the mux'),
   })

   return choices
end

---Kill the background mux server and re-attach, picking up the current config.
---
---There is no WezTerm action for this: the server caches the config it booted
---with, so editing `default_prog` or a domain needs the process replaced rather
---than a Ctrl+Shift+R reload.
---@param window table WezTerm Window
---@param pane table WezTerm Pane
local function restart_mux_server(window, pane)
   local kill = platform.is_win and { 'taskkill', '/IM', 'wezterm-mux-server.exe', '/F' }
      or { 'pkill', '-f', 'wezterm-mux-server' }

   pcall(wezterm.run_child_process, kill)

   -- Attaching spawns a fresh server, since none is listening any more.
   window:perform_action(act.AttachDomain(MUX_DOMAIN), pane)
   window:toast_notification('WezTerm', 'Mux server restarted', nil, 3000)
end

---Second-stage confirmation for the destructive restart
---@param window table WezTerm Window
---@param pane table WezTerm Pane
local function confirm_restart(window, pane)
   window:perform_action(
      act.InputSelector({
         title = 'Restart mux server?',
         choices = {
            { id = 'no', label = label('Cancel', colors.name) },
            {
               id = 'yes',
               label = label('Restart', colors.danger, 'every mux pane is killed'),
            },
         },
         action = wezterm.action_callback(function(win, p, id)
            if id == 'yes' then
               restart_mux_server(win, p)
            end
         end),
      }),
      pane
   )
end

---Open the domain / mux manager
---@param window table WezTerm Window
---@param pane table WezTerm Pane
function M.manager(window, pane)
   window:perform_action(
      act.InputSelector({
         title = 'Domains & Mux',
         choices = M.choices(),
         fuzzy = true,
         fuzzy_description = 'Domain action: ',
         action = wezterm.action_callback(function(win, p, id)
            if not id then
               return
            end

            if id == 'restart' then
               confirm_restart(win, p)
            elseif id == 'detach' then
               win:perform_action(act.DetachDomain('CurrentPaneDomain'), p)
            elseif id == 'attach-mux' then
               win:perform_action(act.AttachDomain(MUX_DOMAIN), p)
            else
               local name = id:sub(#SPAWN_PREFIX + 1)
               win:perform_action(
                  act.SpawnCommandInNewTab({ domain = { DomainName = name } }),
                  p
               )
            end
         end),
      }),
      pane
   )
end

return M
