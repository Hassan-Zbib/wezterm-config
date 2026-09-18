local wezterm = require('wezterm')
local gpu_adapters = require('utils.gpu-adapter')
local backdrops = require('utils.backdrops')
local colors = require('colors.custom')
local p = require('colors.palette')

return {
   -- Quarter-rate on a 240Hz panel. Was 120; dropped while chasing the text
   -- drift that turned out to be `unicode_version` (see config/general.lua), and
   -- kept here by choice -- the renderer was never at fault. The earlier note
   -- claimed 60 was a visible downgrade when scrolling; that was never measured,
   -- so put 120 back if it turns out to be true.
   -- Only costs anything while the screen is actually changing.
   max_fps = 60,
   -- TESTING: WebGpu pinned to the Dx12 dGPU. Known failure modes: WebGpu on the
   -- iGPU stalls on every backdrop swap (it rebuilds the background texture per
   -- set_config_overrides), and on the dGPU it crashed when GHelper powered that
   -- off on battery. Set front_end back to 'OpenGL' if either reappears.
   front_end = 'WebGpu', ---@type 'WebGpu' | 'OpenGL' | 'Software'
   webgpu_power_preference = 'HighPerformance',
   webgpu_preferred_adapter = gpu_adapters:pick_manual('Dx12', 'DiscreteGpu'),
   -- webgpu_preferred_adapter = gpu_adapters:pick_manual('Dx12', 'IntegratedGpu'),
   -- Doubles as the pane split-line thickness: WezTerm draws dividers at
   -- `underline_height` with no separate setting. Raised from 1.5pt so the
   -- divider reads as a boundary; the cost is chunkier text underlines.
   underline_thickness = '2pt',
   warn_about_missing_glyphs = false,

   -- cursor
   -- The `cursor_blink_*` settings are inert under `SteadyBlock` — kept so
   -- switching to a `Blinking*` style just works. `animation_fps` drives only
   -- easing effects (blink, visual bell), not output rendering (`max_fps`), so
   -- its one consumer here is the bell fade below.
   animation_fps = 60,
   cursor_blink_ease_in = 'EaseOut',
   cursor_blink_ease_out = 'EaseOut',
   default_cursor_style = 'SteadyBlock',
   cursor_blink_rate = 650,

   -- color scheme
   colors = colors,

   -- background: pass in `true` if you want wezterm to start with focus mode on (no bg images)
   background = backdrops:initial_options(true),

   -- Visual bell. Agent CLIs ring on completion and permission prompts, so this
   -- fires often -- a short dim pulse, not a strobe. If a busy backdrop swallows
   -- the flash, switch `target` to 'CursorColor', which cannot be washed out.
   visual_bell = {
      fade_in_function = 'EaseOut',
      fade_in_duration_ms = 75,
      fade_out_function = 'EaseIn',
      fade_out_duration_ms = 150,
      target = 'BackgroundColor',
   },

   -- Scrollbar: off, because it carries no signal here. Alt-screen TUIs (yazi,
   -- lazygit) have no scrollback so the thumb fills the track; Claude Code
   -- renders inline and is scrolled with its own keys. Hiding it conditionally
   -- is impossible -- every pane is a ClientPane, whose `is_alt_screen_active()`
   -- is hardcoded false (see the scroll bindings in config/bindings.lua).
   -- Scrolling still works: Shift+PgUp/PgDn, Shift+Home/End, Alt+PgUp/PgDn.
   enable_scroll_bar = false,

   -- tab bar
   enable_tab_bar = true,
   hide_tab_bar_if_only_one_tab = false,
   use_fancy_tab_bar = false,
   tab_bar_at_bottom = false,
   tab_max_width = 25,
   show_tab_index_in_tab_bar = false,
   switch_to_last_active_tab_when_closing_tab = true,

   -- command palette
   command_palette_fg_color = p.lavender,
   command_palette_bg_color = p.crust,
   command_palette_font_size = 12,
   command_palette_rows = 25,

   -- character selector
   char_select_fg_color = p.lavender,
   char_select_bg_color = p.crust,
   char_select_font_size = 12,

   -- pane selector (the big overlay digits)
   pane_select_fg_color = p.crust,
   pane_select_bg_color = p.peach,
   pane_select_font_size = 36,

   -- window
   -- Symmetric because the scrollbar is off. The bar draws INSIDE the right
   -- padding, so restore a wider `right` alongside any `enable_scroll_bar`.
   window_padding = {
      left = 12,
      right = 12,
      top = 10,
      bottom = 7.5,
   },
   window_background_opacity = 1.0,
   win32_system_backdrop = 'Disable',
   window_decorations = 'INTEGRATED_BUTTONS|RESIZE',
   integrated_title_button_alignment = 'Right',
   integrated_title_button_style = 'Windows',
   integrated_title_buttons = { 'Hide', 'Maximize', 'Close' },
   adjust_window_size_when_changing_font_size = false,
   window_close_confirmation = 'NeverPrompt',
   -- stylua: ignore
   tab_bar_style = {
      window_hide           = wezterm.format({ { Foreground = { Color = p.text } },  { Text = ' ' .. wezterm.nerdfonts.md_window_minimize .. ' ' } }),
      window_hide_hover     = wezterm.format({ { Foreground = { Color = p.peach } }, { Text = ' ' .. wezterm.nerdfonts.md_window_minimize .. ' ' } }),
      window_maximize       = wezterm.format({ { Foreground = { Color = p.text } },  { Text = ' ' .. wezterm.nerdfonts.md_window_maximize .. ' ' } }),
      window_maximize_hover = wezterm.format({ { Foreground = { Color = p.peach } }, { Text = ' ' .. wezterm.nerdfonts.md_window_maximize .. ' ' } }),
      window_close          = wezterm.format({ { Foreground = { Color = p.text } },  { Text = ' ' .. wezterm.nerdfonts.md_window_close .. ' ' } }),
      window_close_hover    = wezterm.format({ { Foreground = { Color = p.red } },   { Text = ' ' .. wezterm.nerdfonts.md_window_close .. ' ' } }),
      new_tab               = wezterm.format({ { Foreground = { Color = p.text } },  { Text = ' ' .. wezterm.nerdfonts.md_plus .. ' ' } }),
      new_tab_hover         = wezterm.format({ { Foreground = { Color = p.green } }, { Text = ' ' .. wezterm.nerdfonts.md_plus .. ' ' } }),
   },
   window_frame = {
      active_titlebar_bg = p.ui.titlebar,
      inactive_titlebar_bg = p.ui.titlebar,
      button_bg = p.ui.titlebar,
      button_fg = p.text,
      button_hover_bg = p.base,
      button_hover_fg = p.peach,
      font = wezterm.font({ family = 'JetBrainsMono Nerd Font', weight = 'Bold' }),
      font_size = 11.0,
   },
   -- Inactive panes. HSV multipliers (1.0 = unchanged), applied per-quad.
   --
   -- IMPORTANT: WezTerm only dims a pane's background rectangle when no window
   -- background layer is set (`if self.window_background.is_empty()`). This
   -- config always sets one, focus mode included, so these values reach glyphs
   -- and cell backgrounds ONLY -- pane regions stay pixel-identical. Hence the
   -- hard numbers: all the difference has to be carried by the text. The other
   -- active-pane cues are `colors.split` and `colors.cursor_border`.
   --
   -- Two region-level approaches were tried and dropped: removing the focus-mode
   -- background layer (forces focus mode off pure black, and does nothing under
   -- a backdrop image), and a spotlight overlay (correct, but WezTerm has no
   -- pane-focus event, so it needed a repaint poll and was too laggy).
   inactive_pane_hsb = {
      saturation = 0.55,
      brightness = 0.5,
   },
}
