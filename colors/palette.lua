-- The single source of truth for every color in this config. Anything needing a
-- color should require this file rather than inline a hex literal.
--
-- Two independent halves:
--   * The NEUTRAL RAMP is true greyscale. Catppuccin's own surface/overlay greys
--     are purple-tinted, which reads as a colour cast against a neutral black
--     background and makes a dark theme look muddy. These are flat greys.
--   * The ACCENTS are Catppuccin Mocha, unchanged. Pastels carry further against
--     near-black, so they gained contrast for free when the ramp went neutral.
--
-- The ramp keeps Catppuccin's key names, so consumers keep working.

-- Neutral ramp, darkest to lightest. `text` on `base` is ~16:1 -- deliberately
-- short of pure #000/#fff (~21:1), which makes glyphs bloom against absolute
-- black and is worse on OLED.
-- stylua: ignore
local palette = {
   crust     = '#000000', -- true black: dark text on light accents
   mantle    = '#050505', -- focus-mode background; matches Warp's measured #050505
   base      = '#0d0d0d', -- terminal background
   surface0  = '#1a1a1a',
   surface1  = '#262626', -- inactive tab pill, ANSI black
   surface2  = '#333333', -- ANSI bright black, tab hover pill
   overlay0  = '#4d4d4d', -- pane split line, de-emphasised status text
   overlay1  = '#666666',
   overlay2  = '#808080',
   subtext0  = '#a6a6a6',
   subtext1  = '#cccccc',
   text      = '#e8e8e8', -- terminal foreground

   -- Accents: Catppuccin Mocha, unmodified.
   rosewater = '#f5e0dc',
   flamingo  = '#f2cdcd',
   pink      = '#f5c2e7',
   mauve     = '#cba6f7',
   red       = '#f38ba8',
   maroon    = '#eba0ac',
   peach     = '#fab387',
   yellow    = '#f9e2af',
   green     = '#a6e3a1',
   teal      = '#94e2d5',
   sky       = '#89dceb',
   sapphire  = '#74c7ec',
   blue      = '#89b4fa',
   lavender  = '#b4befe',
}

-- Values that are not part of the ramp or the accents but are shared by more
-- than one module.
-- stylua: ignore
palette.ui = {
   -- Tab bar / status bar fill. Translucent so the backdrop image shows
   -- through; `_alt` is the slightly heavier fill used for the category chip.
   status_bg     = 'rgba(0, 0, 0, 0.4)',
   status_bg_alt = 'rgba(0, 0, 0, 0.55)',

   -- Integrated titlebar. Pure black so it disappears into the window border.
   titlebar      = '#000000',
}

return palette
