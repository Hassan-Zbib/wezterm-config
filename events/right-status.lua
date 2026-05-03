local wezterm = require('wezterm')
local umath = require('utils.math')
local Cells = require('utils.cells')
local backdrops = require('utils.backdrops')
local oled = require('utils.oled-mode')
local platform = require('utils.platform')
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
local ICON_DATE      = nf.fa_calendar
local ICON_RAM       = nf.md_memory
local ICON_CATEGORY  = nf.md_layers
local ICON_OLED_ON   = nf.md_television
local ICON_OLED_OFF  = nf.md_television_off

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
   workspace     = { fg = '#b7bdf8', bg = 'rgba(0, 0, 0, 0.4)' },
   date          = { fg = '#fab387', bg = 'rgba(0, 0, 0, 0.4)' },
   battery       = { fg = '#f9e2af', bg = 'rgba(0, 0, 0, 0.4)' },
   separator     = { fg = '#74c7ec', bg = 'rgba(0, 0, 0, 0.4)' },
   focus_on      = { fg = '#cba6f7', bg = 'rgba(0, 0, 0, 0.4)' },
   focus_off     = { fg = '#6e738d', bg = 'rgba(0, 0, 0, 0.4)' },
   overlay       = { fg = '#89dceb', bg = 'rgba(0, 0, 0, 0.4)' },
   rotate_on     = { fg = '#a6e3a1', bg = 'rgba(0, 0, 0, 0.4)' },
   rotate_off    = { fg = '#6e738d', bg = 'rgba(0, 0, 0, 0.4)' },
   ram           = { fg = '#94e2d5', bg = 'rgba(0, 0, 0, 0.4)' },
   category      = { fg = '#cdd6f4', bg = 'rgba(0, 0, 0, 0.55)' },
   oled_on       = { fg = '#a6e3a1', bg = 'rgba(0, 0, 0, 0.4)' },
   oled_off      = { fg = '#6e738d', bg = 'rgba(0, 0, 0, 0.4)' },
}

-- Segments whose fg should follow the OLED cycle accent.
-- The corresponding `colors` table entries above are the base values restored
-- when OLED mode is off.
local CYCLE_FG_SEGMENTS = {
   'workspace_icon', 'workspace_text',
   'date_icon',      'date_text',
   'ram_icon',       'ram_text',
   'battery_icon',   'battery_text',
   'focus_on',
   'overlay_text',
   'rotate_on',
   'category_text',
   'oled_on',
}

-- Separator-style segments use the dimmer accent variant in OLED mode.
local CYCLE_FG_SEGMENTS_DIM = {
   'workspace_sep', 'separator', 'focus_sep', 'overlay_sep',
   'rotate_sep', 'ram_sep', 'category_sep',
}

local cells = Cells:new()

cells
   :add_segment('workspace_icon', nf.cod_window .. '  ', colors.workspace, attr(attr.intensity('Bold')))
   :add_segment('workspace_text', '', colors.workspace, attr(attr.intensity('Bold')))
   :add_segment('workspace_sep', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('focus_on', nf.md_eye .. ' Focus', colors.focus_on, attr(attr.intensity('Bold')))
   :add_segment('focus_off', nf.md_eye_off .. ' Focus', colors.focus_off)
   :add_segment('focus_sep', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('overlay_text', '', colors.overlay)
   :add_segment('overlay_sep', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('rotate_on', nf.md_rotate_right .. ' ON', colors.rotate_on, attr(attr.intensity('Bold')))
   :add_segment('rotate_off', nf.md_rotate_right .. ' OFF', colors.rotate_off)
   :add_segment('rotate_sep', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('date_icon', ICON_DATE .. '  ', colors.date, attr(attr.intensity('Bold')))
   :add_segment('date_text', '', colors.date, attr(attr.intensity('Bold')))
   :add_segment('separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('ram_icon', ICON_RAM .. '  ', colors.ram)
   :add_segment('ram_text', '', colors.ram, attr(attr.intensity('Bold')))
   :add_segment('ram_sep', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('battery_icon', '', colors.battery)
   :add_segment('battery_text', '', colors.battery, attr(attr.intensity('Bold')))
   :add_segment('category_text', '', colors.category, attr(attr.intensity('Bold')))
   :add_segment('category_sep', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('oled_on', ICON_OLED_ON .. ' Oled', colors.oled_on, attr(attr.intensity('Bold')))
   :add_segment('oled_off', ICON_OLED_OFF .. ' Oled', colors.oled_off)
   :add_segment('oled_sep', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('tail_pad', '   ', colors.separator)

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

local ram_cache = { value = '', last_check = 0 }
local RAM_CACHE_TTL = 5

---@return string RAM usage percentage string e.g. "62%"
local function get_ram_usage()
   local now = os.time()
   if now - ram_cache.last_check < RAM_CACHE_TTL then
      return ram_cache.value
   end
   ram_cache.last_check = now

   if platform.is_win then
      local ok, stdout = wezterm.run_child_process({
         'powershell',
         '-NoProfile',
         '-Command',
         '$os = Get-CimInstance Win32_OperatingSystem; "FreePhysicalMemory=$($os.FreePhysicalMemory)`nTotalVisibleMemorySize=$($os.TotalVisibleMemorySize)"',
      })
      if ok and stdout then
         local total = stdout:match('TotalVisibleMemorySize=(%d+)')
         local free = stdout:match('FreePhysicalMemory=(%d+)')
         if total and free then
            total = tonumber(total)
            free = tonumber(free)
            local pct = math.floor(((total - free) / total) * 100 + 0.5)
            ram_cache.value = pct .. '%'
         end
      end
   else
      local ok, stdout = wezterm.run_child_process({ 'free', '-m' })
      if ok and stdout then
         local total, used = stdout:match('Mem:%s+(%d+)%s+(%d+)')
         if total and used then
            local pct = math.floor((tonumber(used) / tonumber(total)) * 100 + 0.5)
            ram_cache.value = pct .. '%'
         end
      end
   end

   return ram_cache.value
end

---@param opts? Event.RightStatusOptions Default: {date_format = '%a %I:%M %p'}
M.setup = function(opts)
   local valid_opts, err = EVENT_OPTS.validator:validate(opts or {})

   if err then
      wezterm.log_error(err)
   end

   -- Base fg colors used to restore the original palette when OLED mode is off.
   local BASE_FG = {
      workspace_icon = colors.workspace.fg,
      workspace_text = colors.workspace.fg,
      date_icon      = colors.date.fg,
      date_text      = colors.date.fg,
      ram_icon       = colors.ram.fg,
      ram_text       = colors.ram.fg,
      battery_icon   = colors.battery.fg,
      battery_text   = colors.battery.fg,
      focus_on       = colors.focus_on.fg,
      overlay_text   = colors.overlay.fg,
      rotate_on      = colors.rotate_on.fg,
      category_text  = colors.category.fg,
      oled_on        = colors.oled_on.fg,
   }
   local BASE_FG_DIM = {
      workspace_sep = colors.separator.fg,
      separator     = colors.separator.fg,
      focus_sep     = colors.separator.fg,
      overlay_sep   = colors.separator.fg,
      rotate_sep    = colors.separator.fg,
      ram_sep       = colors.separator.fg,
      category_sep  = colors.separator.fg,
   }

   -- Apply OLED palette / restore base palette only when oled.enabled changes
   -- — not on every status tick. Cycling has been removed; OLED-on uses a
   -- single static dim palette.
   local last_oled_enabled = nil

   wezterm.on('update-status', function(window, _pane)
      oled:ensure_window(window)

      local battery_text, battery_icon = battery_info()

      local ram_text = get_ram_usage()

      cells
         :update_segment_text('workspace_text', wezterm.mux.get_active_workspace())
         :update_segment_text('date_text', wezterm.strftime(valid_opts.date_format))
         :update_segment_text('ram_text', ram_text)
         :update_segment_text('battery_icon', battery_icon)
         :update_segment_text('battery_text', battery_text)

      local enabled = oled.enabled
      if enabled ~= last_oled_enabled then
         if enabled then
            local p = oled:current_palette()
            for _, id in ipairs(CYCLE_FG_SEGMENTS) do
               cells:update_segment_colors(id, { fg = p.accent })
            end
            for _, id in ipairs(CYCLE_FG_SEGMENTS_DIM) do
               cells:update_segment_colors(id, { fg = p.accent_dim })
            end
         else
            for id, fg in pairs(BASE_FG) do
               cells:update_segment_colors(id, { fg = fg })
            end
            for id, fg in pairs(BASE_FG_DIM) do
               cells:update_segment_colors(id, { fg = fg })
            end
         end
         last_oled_enabled = enabled
      end

      -- Flash indicators (momentary, only when focus mode is off)
      local cat_label    = backdrops:category_indicator()
      local rotate_label = backdrops:rotate_indicator()
      local overlay_label = backdrops:overlay_indicator()

      if cat_label then
         cells:update_segment_text('category_text', ICON_CATEGORY .. '  ' .. cat_label)
      end
      if overlay_label then
         cells:update_segment_text('overlay_text', nf.md_brightness_6 .. '  ' .. overlay_label)
      end

      local segments = { 'workspace_icon', 'workspace_text', 'workspace_sep' }
      if oled.enabled then
         table.insert(segments, 'oled_on')
      else
         table.insert(segments, 'oled_off')
      end
      table.insert(segments, 'oled_sep')
      if cat_label then
         table.insert(segments, 'category_text')
         table.insert(segments, 'category_sep')
      end
      if backdrops.focus_on then
         table.insert(segments, 'focus_on')
      else
         table.insert(segments, 'focus_off')
      end
      table.insert(segments, 'focus_sep')
      if overlay_label then
         table.insert(segments, 'overlay_text')
         table.insert(segments, 'overlay_sep')
      end
      if rotate_label then
         if backdrops.auto_rotate_enabled then
            table.insert(segments, 'rotate_on')
         else
            table.insert(segments, 'rotate_off')
         end
         table.insert(segments, 'rotate_sep')
      end

      table.insert(segments, 'date_icon')
      table.insert(segments, 'date_text')
      table.insert(segments, 'separator')
      table.insert(segments, 'ram_icon')
      table.insert(segments, 'ram_text')
      table.insert(segments, 'ram_sep')
      table.insert(segments, 'battery_icon')
      table.insert(segments, 'battery_text')
      table.insert(segments, 'tail_pad')

      window:set_right_status(
         wezterm.format(
            cells:render(segments)
         )
      )
   end)
end

return M
