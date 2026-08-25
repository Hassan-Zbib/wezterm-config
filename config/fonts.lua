local wezterm = require('wezterm')
local platform = require('utils.platform')

-- local font_family = 'Maple Mono NF'
local font_family = 'JetBrainsMono Nerd Font'
-- local font_family = 'CartographCF Nerd Font'

local font_size = platform.is_mac and 12 or 9.75

return {
   font = wezterm.font({
      family = font_family,
      weight = 'Medium',
   }),
   font_size = font_size,

   -- Pin every style to a real face in the family. Without these WezTerm is
   -- free to synthesise bold/italic by smearing or slanting the Medium face,
   -- which looks muddy at this size. JetBrainsMono ships all four.
   -- stylua: ignore
   font_rules = {
      { intensity = 'Bold',   italic = false, font = wezterm.font({ family = font_family, weight = 'Bold',   style = 'Normal' }) },
      { intensity = 'Normal', italic = true,  font = wezterm.font({ family = font_family, weight = 'Medium', style = 'Italic' }) },
      { intensity = 'Bold',   italic = true,  font = wezterm.font({ family = font_family, weight = 'Bold',   style = 'Italic' }) },
      { intensity = 'Half',   italic = false, font = wezterm.font({ family = font_family, weight = 'Light',  style = 'Normal' }) },
   },

   -- Extra leading. The single biggest readability knob at this font size.
   line_height = 1.1,

   --ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html#why-doesnt-wezterm-use-the-distro-freetype-or-match-its-configuration
   freetype_load_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
   freetype_render_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
}
