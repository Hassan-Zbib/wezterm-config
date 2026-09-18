-- Near-black neutral scheme with Catppuccin Mocha accents.
-- All hex values come from `colors/palette.lua` — do not inline literals here.
local p = require('colors.palette')

local colorscheme = {
   foreground = p.text,
   background = p.base,
   cursor_bg = p.rosewater,
   cursor_fg = p.crust,

   -- Deliberately NOT `cursor_bg`. WezTerm draws every inactive pane's cursor as
   -- a hollow box in `cursor_border`, so a neutral grey here makes the active
   -- pane the only place a bright rosewater block appears. `p.rosewater` undoes.
   cursor_border = p.overlay2,

   -- Inverted highlight: dark text on a light accent. Much easier to spot than
   -- the upstream surface2/text pairing. To go back to the subtler upstream
   -- look, set these to `p.surface2` / `p.text`.
   selection_bg = p.lavender,
   selection_fg = p.crust,

   -- The 16 ANSI slots every colored CLI draws from. Catppuccin Mocha accents;
   -- black and white come from the neutral ramp.
   --
   -- One deliberate deviation from upstream Catppuccin, which maps bright white
   -- to the *darker* `subtext0` -- tools use bright white for emphasis, so that
   -- ordering makes emphasised text recede. Here it is the brightest value.
   -- stylua: ignore
   ansi = {
      p.surface1, -- black
      p.red,      -- red
      p.green,    -- green
      p.yellow,   -- yellow
      p.blue,     -- blue
      p.pink,     -- magenta/purple
      p.teal,     -- cyan
      p.subtext1, -- white
   },
   -- stylua: ignore
   brights = {
      p.surface2, -- bright black
      p.red,      -- bright red
      p.green,    -- bright green
      p.yellow,   -- bright yellow
      p.blue,     -- bright blue
      p.pink,     -- bright magenta/purple
      p.teal,     -- bright cyan
      p.text,     -- bright white
   },

   tab_bar = {
      background = p.ui.status_bg,
      active_tab = {
         bg_color = p.surface2,
         fg_color = p.text,
      },
      inactive_tab = {
         bg_color = p.surface0,
         fg_color = p.subtext1,
      },
      inactive_tab_hover = {
         bg_color = p.surface0,
         fg_color = p.text,
      },
      new_tab = {
         bg_color = p.base,
         fg_color = p.text,
      },
      new_tab_hover = {
         bg_color = p.mantle,
         fg_color = p.text,
         italic = true,
      },
   },

   -- Overlay hint labels. Left unset these render in WezTerm's defaults
   -- (yellow-on-black), which clashes with everything else. All three overlays
   -- are bound in config/bindings.lua, so all three are themed here.
   -- QuickSelect (Alt+Space)
   quick_select_label_bg = { Color = p.peach },
   quick_select_label_fg = { Color = p.crust },
   quick_select_match_bg = { Color = p.surface1 },
   quick_select_match_fg = { Color = p.lavender },
   -- InputSelector (session restore, backdrop picker, ssh hosts, domain manager)
   -- Deliberately not a coloured chip. WezTerm draws the SELECTED row in reverse
   -- video -- each label segment's foreground becomes its background -- but this
   -- badge keeps its own colour and is never reversed, so a coloured badge always
   -- clashes with the highlight sitting right beside it. Painting it in the
   -- terminal background leaves a plain dim number, which makes the highlighted
   -- row the only coloured thing on the line.
   input_selector_label_bg = { Color = p.base },
   input_selector_label_fg = { Color = p.subtext0 },
   -- Launcher (right-click the new-tab button)
   launcher_label_bg = { Color = p.mauve },
   launcher_label_fg = { Color = p.crust },

   -- The colour the background pulses to on a bell. Was `rosewater`, which is
   -- near-white — fine when the bell never actually fired, but now that the
   -- fade is configured a full-screen white strobe on every agent prompt is
   -- punishing. A gentle lift off the base reads clearly without the glare.
   visual_bell = p.surface1,
   indexed = {
      [16] = p.peach,
      [17] = p.rosewater,
   },
   -- The pane divider: one global colour for every split line, with no
   -- active/inactive variant, so its job is just to make boundaries obvious and
   -- let the dimming and cursor cues say which side is live. Sapphire matches
   -- the active-tab colour; grey would disappear into the text. Thickness is
   -- `underline_thickness` in config/appearance.lua -- there is no separate knob.
   split = p.sapphire,
   compose_cursor = p.flamingo,
}

return colorscheme
