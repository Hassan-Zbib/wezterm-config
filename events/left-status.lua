local wezterm = require('wezterm')
local Cells = require('utils.cells')

local nf = wezterm.nerdfonts
local attr = Cells.attr

local M = {}

local GLYPH_SEMI_CIRCLE_LEFT = nf.ple_left_half_circle_thick --[[ '' ]]
local GLYPH_SEMI_CIRCLE_RIGHT = nf.ple_right_half_circle_thick --[[ '' ]]
local GLYPH_KEY_TABLE = nf.md_table_key --[[ '󱏅' ]]
local GLYPH_KEY = nf.md_key --[[ '󰌆' ]]

---@type table<string, Cells.SegmentColors>
local colors = {
   default = { bg = '#fab387', fg = '#1c1b19' },
   scircle = { bg = '#1e1e2e', fg = '#fab387' },
}

local cells = Cells:new()

cells
   :add_segment(1, GLYPH_SEMI_CIRCLE_LEFT, colors.scircle, attr(attr.intensity('Bold')))
   :add_segment(2, ' ', colors.default, attr(attr.intensity('Bold')))
   :add_segment(3, ' ', colors.default, attr(attr.intensity('Bold')))
   :add_segment(4, GLYPH_SEMI_CIRCLE_RIGHT, colors.scircle, attr(attr.intensity('Bold')))

local hints = {
   { fg = '#89b4fa', text = ' F1:help ' },
}

local function build_hints()
   local result = {}
   for _, h in ipairs(hints) do
      table.insert(result, { Foreground = { Color = h.fg } })
      table.insert(result, { Background = { Color = '#1e1e2e' } })
      table.insert(result, { Attribute = { Intensity = 'Bold' } })
      table.insert(result, { Text = h.text })
   end
   return result
end

M.setup = function()
   wezterm.on('update-right-status', function(window, _pane)
      local name = window:active_key_table()

      if name then
         cells
            :update_segment_text(2, GLYPH_KEY_TABLE)
            :update_segment_text(3, ' ' .. string.upper(name))
         window:set_left_status(wezterm.format(cells:render_all()))
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
