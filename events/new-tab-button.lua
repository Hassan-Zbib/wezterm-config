local wezterm = require('wezterm')
local launch_menu = require('config.launch').launch_menu
local domains = require('config.domains')
local Cells = require('utils.cells')
local p = require('colors.palette')

local nf = wezterm.nerdfonts
local act = wezterm.action
local attr = Cells.attr

local M = {}

---Icon and accent per domain kind. The accent covers the whole row, icon and
---text alike -- see `label`.
-- stylua: ignore
local kinds = {
   default = { icon = nf.oct_terminal,       color = { fg = p.blue } },
   wsl     = { icon = nf.cod_terminal_linux, color = { fg = p.peach } },
   ssh     = { icon = nf.md_ssh,             color = { fg = p.red } },
   unix    = { icon = nf.dev_gnu,            color = { fg = p.mauve } },
}

---Build a launch-menu InputSelector label
---
---Icon and text share one colour, deliberately. WezTerm draws the selected row
---in reverse video, so every segment's foreground becomes its background: a
---coloured icon beside differently-coloured text highlights as two mismatched
---blocks instead of one bar. The glyph still distinguishes the domain kind.
---@param kind {icon: string, color: Cells.SegmentColors}
---@param text string
---@return string
local function label(kind, text)
   local cells = Cells:new()
      :add_segment('icon', ' ' .. kind.icon .. ' ', kind.color)
      :add_segment('text', text, kind.color, attr(attr.intensity('Bold')))
   return wezterm.format(cells:render({ 'icon', 'text' }))
end

local function build_choices()
   local choices = {}
   local choices_data = {}
   local idx = 1

   -- Add launch menu items (DefaultDomain)
   for _, v in ipairs(launch_menu) do
      table.insert(choices, {
         id = tostring(idx),
         label = label(kinds.default, v.label),
      })
      table.insert(choices_data, {
         args = v.args,
         domain = 'DefaultDomain',
      })
      idx = idx + 1
   end

   -- Add WSL domains
   for _, v in ipairs(domains.wsl_domains) do
      table.insert(choices, {
         id = tostring(idx),
         label = label(kinds.wsl, v.name),
      })
      table.insert(choices_data, {
         domain = { DomainName = v.name },
      })
      idx = idx + 1
   end

   -- Add SSH domains
   for _, v in ipairs(domains.ssh_domains) do
      table.insert(choices, {
         id = tostring(idx),
         label = label(kinds.ssh, v.name),
      })
      table.insert(choices_data, {
         domain = { DomainName = v.name },
      })
      idx = idx + 1
   end

   -- Add Unix domains
   for _, v in ipairs(domains.unix_domains) do
      table.insert(choices, {
         id = tostring(idx),
         label = label(kinds.unix, v.name),
      })
      table.insert(choices_data, {
         domain = { DomainName = v.name },
      })
      idx = idx + 1
   end

   return choices, choices_data
end

local choices, choices_data = build_choices()

M.setup = function()
   wezterm.on('new-tab-button-click', function(window, pane, button, default_action)
      if default_action and button == 'Left' then
         window:perform_action(default_action, pane)
      end

      if default_action and button == 'Right' then
         window:perform_action(
            act.InputSelector({
               title = 'InputSelector: Launch Menu',
               choices = choices,
               fuzzy = true,
               fuzzy_description = nf.md_rocket .. ' Select a lauch item: ',
               action = wezterm.action_callback(function(_window, _pane, id, label)
                  if not id and not label then
                     return
                  else
                     wezterm.log_info('you selected ', id, label)
                     wezterm.log_info(choices_data[tonumber(id)])
                     window:perform_action(
                        act.SpawnCommandInNewTab(choices_data[tonumber(id)]),
                        pane
                     )
                  end
               end),
            }),
            pane
         )
      end
      return false
   end)
end

return M
