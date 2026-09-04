local wezterm = require('wezterm')

return {
   -- behaviours
   default_cwd = wezterm.home_dir .. '/Desktop/GitHub',
   automatically_reload_config = true,
   exit_behavior = 'CloseOnCleanExit', -- if the shell program exited with a successful status
   exit_behavior_messaging = 'Verbose',
   status_update_interval = 1000,
   audible_bell = 'SystemBeep',

   scrollback_lines = 50000,

   -- The GUI and the mux server must agree on a workspace name, otherwise
   -- `wezterm connect mux` attaches looking for "default", doesn't find it, and
   -- spawns a second empty window alongside the one the server already built.
   default_workspace = 'main',

   -- Must stay false. WezTerm's kitty-protocol encoder sends the SHIFTED
   -- codepoint for non-letter keys instead of the base one (wezterm#2546), so
   -- Shift+/ arrives as `CSI 63;..u` rather than the spec's `CSI 47;2u` and any
   -- TUI that negotiates the protocol -- Claude Code, Neovim -- never receives a
   -- literal `?`. A plain bash prompt is unaffected because it never requests
   -- the protocol, which is why this looks like "Shift is broken, but only
   -- sometimes". Shift+Enter keeps working either way: it's an explicit
   -- SendString in config/bindings.lua, which bypasses key encoding entirely.
   enable_kitty_keyboard = false,

   hyperlink_rules = {
      -- Matches: a URL in parens: (URL)
      {
         regex = '\\((\\w+://\\S+)\\)',
         format = '$1',
         highlight = 1,
      },
      -- Matches: a URL in brackets: [URL]
      {
         regex = '\\[(\\w+://\\S+)\\]',
         format = '$1',
         highlight = 1,
      },
      -- Matches: a URL in curly braces: {URL}
      {
         regex = '\\{(\\w+://\\S+)\\}',
         format = '$1',
         highlight = 1,
      },
      -- Matches: a URL in angle brackets: <URL>
      {
         regex = '<(\\w+://\\S+)>',
         format = '$1',
         highlight = 1,
      },
      -- Then handle URLs not wrapped in brackets
      {
         regex = '\\b\\w+://\\S+[)/a-zA-Z0-9-]+',
         format = '$0',
      },
      -- implicit mailto link
      {
         regex = '\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b',
         format = 'mailto:$0',
      },
   },
}
