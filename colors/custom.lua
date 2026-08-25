-- Near-black neutral scheme with Catppuccin Mocha accents.
-- All hex values come from `colors/palette.lua` — do not inline literals here.
local p = require('colors.palette')

local colorscheme = {
   foreground = p.text,
   background = p.base,
   cursor_bg = p.rosewater,
   cursor_fg = p.crust,

   -- Deliberately NOT `cursor_bg`. WezTerm forces the cursor in every inactive
   -- pane to a hollow, non-blinking outline box drawn in `cursor_border` — any
   -- shape, no config needed. While both were rosewater that built-in cue was
   -- wasted: filled-rosewater vs hollow-rosewater is a weak read at a glance.
   -- A neutral grey outline makes the active pane the only place a bright
   -- rosewater block appears. Set back to `p.rosewater` to undo.
   cursor_border = p.overlay2,

   -- Inverted highlight: dark text on a light accent. Much easier to spot than
   -- the upstream surface2/text pairing. To go back to the subtler upstream
   -- look, set these to `p.surface2` / `p.text`.
   selection_bg = p.lavender,
   selection_fg = p.crust,

   -- The 16 ANSI slots every colored CLI draws from — eza, git, starship, fzf,
   -- bat, delta, yazi, lazygit, and any TUI. Catppuccin Mocha accents; the
   -- black and white slots come from the neutral ramp.
   --
   -- NOTE: one deliberate deviation from upstream Catppuccin, which maps white
   -- to `subtext1` and bright white to the *darker* `subtext0`. Tools use
   -- bright white for emphasis, so that ordering makes emphasised text recede.
   -- Bright white is the brightest value here instead.
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
   -- InputSelector (session restore, backdrop picker, ssh hosts)
   input_selector_label_bg = { Color = p.sapphire },
   input_selector_label_fg = { Color = p.crust },
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
   scrollbar_thumb = p.surface2,
   -- The pane divider. WezTerm has no per-pane borders and no active/inactive
   -- divider variant — this is one global colour for every split line in the
   -- tab — so the job here is just to make the boundaries themselves obvious,
   -- and let the dimming/cursor cues say which side is live.
   --
   -- Grey (`overlay1`) reads as chrome and disappears into the text. Sapphire
   -- is already the active-tab colour, so pane edges and the active tab pill
   -- speak the same language. Its thickness is `underline_thickness` (see
   -- config/appearance.lua) — there is no separate knob for it.
   split = p.sapphire,
   compose_cursor = p.flamingo,
}

return colorscheme
