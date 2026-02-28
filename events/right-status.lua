local wezterm = require('wezterm')
local umath = require('utils.math')
local Cells = require('utils.cells')
local OptsValidator = require('utils.opts-validator')

---@alias Event.RightStatusOptions { date_format?: string }

local EVENT_OPTS = {}

---@type OptsSchema
EVENT_OPTS.schema = {
   {
      name = 'date_format',
      type = 'string',
      default = '%a %I:%M %p',
   },
}
EVENT_OPTS.validator = OptsValidator:new(EVENT_OPTS.schema)

local nf = wezterm.nerdfonts
local attr = Cells.attr

local M = {}

local ICON_SEPARATOR = nf.oct_dash
local ICON_DATE = nf.fa_calendar

---@type string[]
local discharging_icons = {
   nf.md_battery_10,
   nf.md_battery_20,
   nf.md_battery_30,
   nf.md_battery_40,
   nf.md_battery_50,
   nf.md_battery_60,
   nf.md_battery_70,
   nf.md_battery_80,
   nf.md_battery_90,
   nf.md_battery,
}
---@type string[]
local charging_icons = {
   nf.md_battery_charging_10,
   nf.md_battery_charging_20,
   nf.md_battery_charging_30,
   nf.md_battery_charging_40,
   nf.md_battery_charging_50,
   nf.md_battery_charging_60,
   nf.md_battery_charging_70,
   nf.md_battery_charging_80,
   nf.md_battery_charging_90,
   nf.md_battery_charging,
}

---@type table<string, Cells.SegmentColors>
-- stylua: ignore
local colors = {
   date          = { fg = '#fab387', bg = 'rgba(0, 0, 0, 0.4)' },
   battery       = { fg = '#f9e2af', bg = 'rgba(0, 0, 0, 0.4)' },
   separator     = { fg = '#74c7ec', bg = 'rgba(0, 0, 0, 0.4)' },
   agent_working = { fg = '#a6e3a1', bg = 'rgba(0, 0, 0, 0.4)' },
   agent_waiting = { fg = '#f9e2af', bg = 'rgba(0, 0, 0, 0.4)' },
}

local cells = Cells:new()

cells
   :add_segment('agent_working', '', colors.agent_working, attr(attr.intensity('Bold')))
   :add_segment('agent_waiting', '', colors.agent_waiting, attr(attr.intensity('Bold')))
   :add_segment('agent_sep', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('date_icon', ICON_DATE .. '  ', colors.date, attr(attr.intensity('Bold')))
   :add_segment('date_text', '', colors.date, attr(attr.intensity('Bold')))
   :add_segment('separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('battery_icon', '', colors.battery)
   :add_segment('battery_text', '', colors.battery, attr(attr.intensity('Bold')))

---@return string, string
local function battery_info()
   local charge = ''
   local icon = ''

   for _, b in ipairs(wezterm.battery_info()) do
      local idx = umath.clamp(umath.round(b.state_of_charge * 10), 1, 10)
      charge = string.format('%.0f%%', b.state_of_charge * 100)

      if b.state == 'Charging' then
         icon = charging_icons[idx]
      else
         icon = discharging_icons[idx]
      end
   end

   return charge, icon .. ' '
end

---@param opts? Event.RightStatusOptions Default: {date_format = '%a %I:%M %p'}
M.setup = function(opts)
   local valid_opts, err = EVENT_OPTS.validator:validate(opts or {})

   if err then
      wezterm.log_error(err)
   end

   wezterm.on('update-right-status', function(window, _pane)
      local battery_text, battery_icon = battery_info()

      -- Agent status from wezterm-agent-deck plugin
      local working_text = ''
      local waiting_text = ''
      local has_agents = false
      local ok, agent_deck = pcall(wezterm.plugin.require, 'https://github.com/Eric162/wezterm-agent-deck')
      if ok then
         local counts = agent_deck.count_agents_by_status()
         if counts.working and counts.working > 0 then
            working_text = '● ' .. counts.working
            has_agents = true
         end
         if counts.waiting and counts.waiting > 0 then
            waiting_text = '◔ ' .. counts.waiting
            has_agents = true
         end
      end

      cells
         :update_segment_text('agent_working', working_text)
         :update_segment_text('agent_waiting', waiting_text)
         :update_segment_text('date_text', wezterm.strftime(valid_opts.date_format))
         :update_segment_text('battery_icon', battery_icon)
         :update_segment_text('battery_text', battery_text)

      local segments = {}
      if has_agents then
         if working_text ~= '' then table.insert(segments, 'agent_working') end
         if waiting_text ~= '' then table.insert(segments, 'agent_waiting') end
         table.insert(segments, 'agent_sep')
      end
      table.insert(segments, 'date_icon')
      table.insert(segments, 'date_text')
      table.insert(segments, 'separator')
      table.insert(segments, 'battery_icon')
      table.insert(segments, 'battery_text')

      window:set_right_status(
         wezterm.format(
            cells:render(segments)
         )
      )
   end)
end

return M
