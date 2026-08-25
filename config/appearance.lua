local wezterm = require('wezterm')
local gpu_adapters = require('utils.gpu-adapter')
local backdrops = require('utils.backdrops')
local colors = require('colors.custom')
local p = require('colors.palette')

return {
   -- The panel is 240Hz, so this is already a deliberate half-rate cap rather
   -- than overshoot — dropping it to 60 would be a visible downgrade when
   -- scrolling scrollback. It only costs anything while the screen is actually
   -- changing, which for agent work means during streaming output.
   max_fps = 120,
   -- TESTING: WebGpu pinned to the Dx12 dGPU. Prior findings, kept for reference:
   -- WebGpu on the iGPU stalls on every backdrop swap (it rebuilds the
   -- background texture on each set_config_overrides), and WebGpu pinned to
   -- the dGPU crashed when GHelper powered it off on battery. OpenGL was the
   -- stable choice; set front_end back to 'OpenGL' if either issue reappears.
   front_end = 'WebGpu', ---@type 'WebGpu' | 'OpenGL' | 'Software'
   webgpu_power_preference = 'HighPerformance',
   webgpu_preferred_adapter = gpu_adapters:pick_manual('Dx12', 'DiscreteGpu'),
   -- webgpu_preferred_adapter = gpu_adapters:pick_manual('Dx12', 'IntegratedGpu'),
   -- Doubles as the pane split-line thickness: WezTerm draws dividers at
   -- `underline_height` and exposes no separate setting for them. Bumped from
   -- 1.5pt to give the sapphire divider enough weight to read as a boundary.
   -- The side effect is chunkier text underlines — revert to '1.5pt' if that
   -- bothers you more than thin dividers do.
   underline_thickness = '2pt',
   warn_about_missing_glyphs = false,

   -- cursor
   -- NOTE: the three `cursor_blink_*` settings below only take effect for the
   -- `Blinking*` cursor styles. They are inert while the style is `SteadyBlock`
   -- — kept here so switching to `BlinkingBlock`/`BlinkingBar` just works.
   --
   -- `animation_fps` only drives easing effects (blinking cursor, blinking
   -- text, the visual bell) — not general output rendering, which is `max_fps`.
   -- With a steady cursor its only real consumer is the visual bell fade below,
   -- and 60fps is already smooth for a 150ms fade.
   animation_fps = 60,
   cursor_blink_ease_in = 'EaseOut',
   cursor_blink_ease_out = 'EaseOut',
   default_cursor_style = 'SteadyBlock',
   cursor_blink_rate = 650,

   -- color scheme
   colors = colors,

   -- background: pass in `true` if you want wezterm to start with focus mode on (no bg images)
   background = backdrops:initial_options(true),

   -- Visual bell. Agent CLIs ring the terminal bell on completion and on
   -- permission prompts, so this fires often — a short, dim pulse rather than a
   -- full-brightness strobe. The flash colour is `colors.visual_bell`.
   -- If a busy backdrop swallows the background flash, switch `target` to
   -- 'CursorColor'; the cursor is always drawn, so it cannot be washed out.
   visual_bell = {
      fade_in_function = 'EaseOut',
      fade_in_duration_ms = 75,
      fade_out_function = 'EaseIn',
      fade_out_duration_ms = 150,
      target = 'BackgroundColor',
   },

   -- scrollbar
   enable_scroll_bar = true,

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
   -- NOTE: `right` must leave room for the scrollbar — it is drawn inside the
   -- right padding, so `enable_scroll_bar` does nothing when this is 0.
   window_padding = {
      left = 12,
      right = 16,
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
   -- Inactive panes. These are HSV multipliers (1.0 = unchanged), applied as a
   -- per-quad GPU transform.
   --
   -- IMPORTANT: this dims a pane's *background rectangle* only when no window
   -- background layer is set — WezTerm guards that fill with
   -- `if self.window_background.is_empty()`. This config always sets
   -- `background` layers (focus mode included, which paints a solid colour), so
   -- these values reach glyphs and cell backgrounds ONLY. Pane regions are
   -- always pixel-identical. That is why the previous 0.85/0.7 read as nothing.
   --
   -- Hence the harder numbers: with only text to work with, the whole
   -- difference has to be carried by the text. The other two active-pane cues
   -- are `colors.split` (the divider) and `colors.cursor_border` (WezTerm draws
   -- inactive panes' cursors as a hollow box in that colour).
   --
   -- Two region-level approaches were built and dropped, so they do not get
   -- retried:
   --   1. Removing the focus-mode background layer, which lets the fill above
   --      be drawn again. Works, but forces focus mode off pure black and does
   --      nothing while a backdrop image is up, since the image is itself the
   --      suppressing layer.
   --   2. A Warp-style spotlight — a black rectangle layer positioned over the
   --      active pane on a grey fill, which is the only way to get the active
   --      pane DARKER than the others (this setting only multiplies downward).
   --      Correct visually, but WezTerm has no pane-focus event, so it had to
   --      repaint via `set_config_overrides` on every pane switch plus an
   --      `update-status` poll. Too laggy to keep.
   inactive_pane_hsb = {
      saturation = 0.55,
      brightness = 0.5,
   },
}
