local wezterm = require('wezterm')
local gpu_adapters = require('utils.gpu-adapter')
local backdrops = require('utils.backdrops')
local colors = require('colors.custom')

return {
   max_fps = 60,
   front_end = 'OpenGL', ---@type 'WebGpu' | 'OpenGL' | 'Software'
   webgpu_power_preference = 'HighPerformance',
   webgpu_preferred_adapter = gpu_adapters:pick_best(),
   -- webgpu_preferred_adapter = gpu_adapters:pick_manual('Dx12', 'IntegratedGpu'),
   -- webgpu_preferred_adapter = gpu_adapters:pick_manual('Gl', 'Other'),
   underline_thickness = '1.5pt',
   warn_about_missing_glyphs = false,

   -- cursor
   animation_fps = 60,
   cursor_blink_ease_in = 'EaseOut',
   cursor_blink_ease_out = 'EaseOut',
   default_cursor_style = 'SteadyBlock',
   cursor_blink_rate = 650,

   -- color scheme
   colors = colors,

   -- background: pass in `true` if you want wezterm to start with focus mode on (no bg images)
   background = backdrops:initial_options(true),

   -- scrollbar
   enable_scroll_bar = true,

   -- tab bar
   enable_tab_bar = true,
   hide_tab_bar_if_only_one_tab = false,
   use_fancy_tab_bar = false,
   tab_bar_at_bottom = true,
   tab_max_width = 25,
   show_tab_index_in_tab_bar = false,
   switch_to_last_active_tab_when_closing_tab = true,

   -- command palette
   command_palette_fg_color = '#b4befe',
   command_palette_bg_color = '#11111b',
   command_palette_font_size = 12,
   command_palette_rows = 25,

   -- window
   window_padding = {
      left = 0,
      right = 0,
      top = 10,
      bottom = 7.5,
   },
   window_background_opacity = 0.80,
   win32_system_backdrop = 'Acrylic',
   window_decorations = 'INTEGRATED_BUTTONS|RESIZE',
   integrated_title_button_alignment = 'Right',
   integrated_title_button_style = 'Windows',
   integrated_title_buttons = { 'Hide', 'Maximize', 'Close' },
   adjust_window_size_when_changing_font_size = false,
   window_close_confirmation = 'NeverPrompt',
   tab_bar_style = {
      window_hide           = wezterm.format({ { Foreground = { Color = '#cdd6f4' } }, { Text = ' ' .. wezterm.nerdfonts.md_window_minimize .. ' ' } }),
      window_hide_hover     = wezterm.format({ { Foreground = { Color = '#fab387' } }, { Text = ' ' .. wezterm.nerdfonts.md_window_minimize .. ' ' } }),
      window_maximize       = wezterm.format({ { Foreground = { Color = '#cdd6f4' } }, { Text = ' ' .. wezterm.nerdfonts.md_window_maximize .. ' ' } }),
      window_maximize_hover = wezterm.format({ { Foreground = { Color = '#fab387' } }, { Text = ' ' .. wezterm.nerdfonts.md_window_maximize .. ' ' } }),
      window_close          = wezterm.format({ { Foreground = { Color = '#cdd6f4' } }, { Text = ' ' .. wezterm.nerdfonts.md_window_close .. ' ' } }),
      window_close_hover    = wezterm.format({ { Foreground = { Color = '#f38ba8' } }, { Text = ' ' .. wezterm.nerdfonts.md_window_close .. ' ' } }),
      new_tab               = wezterm.format({ { Foreground = { Color = '#cdd6f4' } }, { Text = ' ' .. wezterm.nerdfonts.md_plus .. ' ' } }),
      new_tab_hover         = wezterm.format({ { Foreground = { Color = '#a6e3a1' } }, { Text = ' ' .. wezterm.nerdfonts.md_plus .. ' ' } }),
   },
   window_frame = {
      active_titlebar_bg = '#000000',
      inactive_titlebar_bg = '#000000',
      button_bg = '#000000',
      button_fg = '#cdd6f4',
      button_hover_bg = '#1f1f28',
      button_hover_fg = '#fab387',
      font = wezterm.font({ family = 'JetBrainsMono Nerd Font', weight = 'Bold' }),
      font_size = 11.0,
   },
   inactive_pane_hsb = {
      saturation = 0.85,
      brightness = 0.5,
   },
}
