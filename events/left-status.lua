local wezterm = require('wezterm')
local Cells = require('utils.cells')
local backdrops = require('utils.backdrops')
local p = require('colors.palette')

local nf = wezterm.nerdfonts
local attr = Cells.attr

local M = {}

local GLYPH_SEMI_CIRCLE_LEFT = nf.ple_left_half_circle_thick --[[ '' ]]
local GLYPH_SEMI_CIRCLE_RIGHT = nf.ple_right_half_circle_thick --[[ '' ]]
local GLYPH_KEY_TABLE = nf.md_table_key --[[ '󱏅' ]]
local GLYPH_KEY = nf.md_key --[[ '󰌆' ]]

---@type table<string, Cells.SegmentColors>
local colors = {
   default = { bg = p.peach, fg = p.crust },
   scircle = { bg = p.base, fg = p.peach },
}

local cells = Cells:new()

cells
   :add_segment(1, GLYPH_SEMI_CIRCLE_LEFT, colors.scircle, attr(attr.intensity('Bold')))
   :add_segment(2, ' ', colors.default, attr(attr.intensity('Bold')))
   :add_segment(3, ' ', colors.default, attr(attr.intensity('Bold')))
   :add_segment(4, GLYPH_SEMI_CIRCLE_RIGHT, colors.scircle, attr(attr.intensity('Bold')))

local hints = {
   { fg = p.blue, text = ' F1:help ' },
}

local copy_mode_hint_items = {
   { fg = p.green,    text = '  ←↑↓→ ' },
   { fg = p.text,     text = 'move' },
   { fg = p.overlay0, text = '  ·  ' },
   { fg = p.green,    text = 'Ctrl+←→/wb ' },
   { fg = p.text,     text = 'word' },
   { fg = p.overlay0, text = '  ·  ' },
   { fg = p.yellow,   text = 'v/V/^v ' },
   { fg = p.text,     text = 'select' },
   { fg = p.overlay0, text = '  ·  ' },
   { fg = p.blue,     text = 'y ' },
   { fg = p.text,     text = 'copy' },
   { fg = p.overlay0, text = '  ·  ' },
   { fg = p.mauve,    text = '/ ' },
   { fg = p.text,     text = 'search' },
   { fg = p.overlay0, text = '  ·  ' },
   { fg = p.red,      text = 'q ' },
   { fg = p.text,     text = 'exit  ' },
}

local function build_hints()
   local result = {}
   for _, h in ipairs(hints) do
      table.insert(result, { Foreground = { Color = h.fg } })
      table.insert(result, { Background = { Color = p.base } })
      table.insert(result, { Attribute = { Intensity = 'Bold' } })
      table.insert(result, { Text = h.text })
   end
   return result
end

local function build_copy_mode_hints()
   local result = {}
   for _, h in ipairs(copy_mode_hint_items) do
      table.insert(result, { Foreground = { Color = h.fg } })
      table.insert(result, { Background = { Color = p.base } })
      table.insert(result, { Attribute = { Intensity = 'Bold' } })
      table.insert(result, { Text = h.text })
   end
   return result
end

M.setup = function()
   wezterm.on('update-status', function(window, _pane)
      local name = window:active_key_table()

      if name then
         local label = ' ' .. string.upper(name)
         if name == 'browse_backdrop' then
            label = label .. '  [' .. backdrops.current_idx .. '/' .. #backdrops.images .. ']'
         end
         cells
            :update_segment_text(2, GLYPH_KEY_TABLE)
            :update_segment_text(3, label)
         local rendered = cells:render({ 1, 2, 3, 4 })
         if name == 'copy_mode' then
            for _, item in ipairs(build_copy_mode_hints()) do
               table.insert(rendered, item)
            end
         end
         window:set_left_status(wezterm.format(rendered))
         return
      end

      if window:leader_is_active() then
         cells:update_segment_text(2, GLYPH_KEY):update_segment_text(3, ' ')
         window:set_left_status(wezterm.format(cells:render_all()))
         return
      end

      window:set_left_status(wezterm.format(build_hints()))
   end)
end

return M
