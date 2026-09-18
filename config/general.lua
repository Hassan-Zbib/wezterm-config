local wezterm = require('wezterm')

return {
   -- behaviours
   default_cwd = wezterm.home_dir .. '/Desktop/GitHub',
   automatically_reload_config = true,
   exit_behavior = 'CloseOnCleanExit', -- if the shell program exited with a successful status
   exit_behavior_messaging = 'Verbose',
   status_update_interval = 1000,
   audible_bell = 'SystemBeep',

   -- WezTerm defaults to 9, where an emoji-presentation sequence such as
   -- U+27A1 U+FE0F measures ONE cell. Ink's string-width -- so Claude Code, and
   -- every modern TUI -- measures it as two. Each one left WezTerm's cursor a
   -- column behind the app's, and the error accumulated down the buffer until
   -- text slid off the left edge; a resize "fixed" it only because the app then
   -- repainted from its own model. Verified with a CSI 6n probe: that sequence
   -- is width 1 at version 9 and width 2 at 14, with every other character
   -- tested (·, §, →, …, CJK) identical across both.
   --
   -- Applies to every pane, so a TUI still built against Unicode 9 tables would
   -- now disagree in the other direction.
   unicode_version = 14,

   -- Per-pane, so this multiplies across every split. 50k lines held roughly
   -- five times the memory of this for no practical gain -- searching back that
   -- far is what the shell's own history is for.
   scrollback_lines = 10000,

   -- The GUI and the mux server must agree on a workspace name, otherwise
   -- `wezterm connect mux` attaches looking for "default", doesn't find it, and
   -- spawns a second empty window alongside the one the server already built.
   default_workspace = 'main',

   -- Must stay false. WezTerm's kitty-protocol encoder sends the SHIFTED
   -- codepoint for non-letter keys (wezterm#2546), so Shift+/ arrives as
   -- `CSI 63;..u` instead of `CSI 47;2u` and any TUI that negotiates the
   -- protocol -- Claude Code, Neovim -- never receives a literal `?`. A plain
   -- prompt never requests the protocol, which is why it looks like "Shift is
   -- broken, but only sometimes". Shift+Enter is unaffected: it is an explicit
   -- SendString in config/bindings.lua, bypassing key encoding.
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
