local wezterm = require('wezterm')
local act = wezterm.action
local platform = require('utils.platform')
local backdrops = require('utils.backdrops')
local sessions = require('utils.sessions')
local ssh_hosts = require('utils.ssh-hosts')

local mod = {}
local key = {}

if platform.is_mac then
   mod.SUPER = 'SUPER'
   mod.SUPER_REV = 'SUPER|CTRL'
   key.S = 'Cmd'
   key.SR = 'Cmd+Ctrl'
elseif platform.is_win or platform.is_linux then
   mod.SUPER = 'ALT'
   mod.SUPER_REV = 'ALT|CTRL'
   key.S = 'Alt'
   key.SR = 'Alt+Ctrl'
end

local M = {}

M.setup = function()
   wezterm.on('augment-command-palette', function(window, pane)
      -- stylua: ignore
      return {
         -- misc
         {
            brief = 'Cheatsheet / Help  [F1]',
            icon = 'md_help_circle_outline',
            action = wezterm.action_callback(function(win, p)
               local home = wezterm.home_dir:gsub('\\', '/')
               local drive = home:sub(1, 1):lower()
               local unix_home = '/' .. drive .. home:sub(3)
               local script = unix_home .. '/Desktop/GitHub/wezterm-config/scripts/cheatsheet.sh'
               win:perform_action(act.SpawnCommandInNewTab({
                  args = { 'C:\\Program Files\\Git\\bin\\bash.exe', '--login', '-c', script },
               }), p)
            end),
         },
         {
            brief = 'Show Launcher  [F3]',
            icon = 'md_rocket_launch',
            action = act.ShowLauncher,
         },
         {
            brief = 'Fuzzy Tab Search  [F4]',
            icon = 'md_tab_search',
            action = act.ShowLauncherArgs({ flags = 'FUZZY|TABS' }),
         },
         {
            brief = 'Fuzzy Workspace Search  [F5]',
            icon = 'cod_window',
            action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }),
         },
         {
            brief = 'Toggle Agent Deck Notifications  [F6]',
            icon = 'md_bell',
            action = wezterm.action_callback(function(win, _p)
               local ok, agent_deck = pcall(wezterm.plugin.require, 'https://github.com/Eric162/wezterm-agent-deck')
               if ok then
                  local cfg = agent_deck.get_config()
                  cfg.notifications.enabled = not cfg.notifications.enabled
                  local status = cfg.notifications.enabled and 'ON' or 'OFF'
                  win:toast_notification('Agent Deck', 'Notifications ' .. status, nil, 3000)
               end
            end),
         },
         {
            brief = 'SSH Host Connect  [F7]',
            icon = 'md_ssh',
            action = wezterm.action_callback(function(win, p)
               win:perform_action(act.InputSelector({
                  title = 'SSH Hosts',
                  choices = ssh_hosts.choices(),
                  fuzzy = true,
                  fuzzy_description = 'Connect to SSH Host: ',
                  action = wezterm.action_callback(function(inner_win, inner_pane, id)
                     if id then
                        ssh_hosts.connect(inner_pane, id)
                     end
                  end),
               }), p)
            end),
         },
         {
            brief = 'Copy Mode  [F8]',
            icon = 'md_content_copy',
            action = act.ActivateCopyMode,
         },
         {
            brief = 'Save Session  [F9]',
            icon = 'md_content_save',
            action = wezterm.action_callback(function(win, p)
               sessions.save(win, p)
            end),
         },
         {
            brief = 'Restore Session  [F10]',
            icon = 'md_backup_restore',
            action = wezterm.action_callback(function(win, p)
               win:perform_action(act.InputSelector({
                  title = 'Restore Session',
                  choices = sessions.choices(),
                  fuzzy = true,
                  fuzzy_description = 'Select Session: ',
                  action = wezterm.action_callback(function(inner_win, inner_pane, id)
                     if id then
                        sessions.restore(inner_win, inner_pane, id)
                     end
                  end),
               }), p)
            end),
         },
         {
            brief = 'Toggle Fullscreen  [F11]',
            icon = 'md_fullscreen',
            action = act.ToggleFullScreen,
         },
         {
            brief = 'Debug Overlay  [F12]',
            icon = 'md_bug',
            action = act.ShowDebugOverlay,
         },
         {
            brief = 'Search  [' .. key.S .. '+F]',
            icon = 'md_text_search',
            action = act.Search({ CaseInSensitiveString = '' }),
         },
         {
            brief = 'Quick URL Select  [' .. key.SR .. '+U]',
            icon = 'md_link',
            action = wezterm.action.QuickSelectArgs({
               label = 'open url',
               patterns = {
                  '\\((https?://\\S+)\\)',
                  '\\[(https?://\\S+)\\]',
                  '\\{(https?://\\S+)\\}',
                  '<(https?://\\S+)>',
                  '\\bhttps?://\\S+[)/a-zA-Z0-9-]+'
               },
               action = wezterm.action_callback(function(win, p)
                  local url = win:get_selection_text_for_pane(p)
                  wezterm.log_info('opening: ' .. url)
                  wezterm.open_with(url)
               end),
            }),
         },

         -- tabs
         {
            brief = 'New Tab  [' .. key.S .. '+T]',
            icon = 'md_tab_plus',
            action = act.SpawnTab('DefaultDomain'),
         },
         {
            brief = 'New WSL Tab  [' .. key.SR .. '+T]',
            icon = 'linux_tux',
            action = act.SpawnTab({ DomainName = 'wsl:ubuntu-fish' }),
         },
         {
            brief = 'Close Tab  [' .. key.SR .. '+W]',
            icon = 'md_tab_remove',
            action = act.CloseCurrentTab({ confirm = false }),
         },
         {
            brief = 'Rename Tab  [' .. key.S .. '+0]',
            icon = 'md_rename',
            action = act.EmitEvent('tabs.manual-update-tab-title'),
         },
         {
            brief = 'Reset Tab Title  [' .. key.SR .. '+0]',
            icon = 'md_undo',
            action = act.EmitEvent('tabs.reset-tab-title'),
         },
         {
            brief = 'Toggle Tab Bar  [' .. key.S .. '+9]',
            icon = 'md_eye_off',
            action = act.EmitEvent('tabs.toggle-tab-bar'),
         },

         -- window
         {
            brief = 'New Window  [' .. key.S .. '+N]',
            icon = 'md_window_open',
            action = act.SpawnWindow,
         },

         -- background
         {
            brief = 'Random Background  [' .. key.S .. '+/]',
            icon = 'md_image_multiple',
            action = wezterm.action_callback(function(win, _p)
               backdrops:random(win)
            end),
         },
         {
            brief = 'Previous Background  [' .. key.S .. '+,]',
            icon = 'md_arrow_left',
            action = wezterm.action_callback(function(win, _p)
               backdrops:cycle_back(win)
            end),
         },
         {
            brief = 'Next Background  [' .. key.S .. '+.]',
            icon = 'md_arrow_right',
            action = wezterm.action_callback(function(win, _p)
               backdrops:cycle_forward(win)
            end),
         },
         {
            brief = 'Select Background  [' .. key.SR .. '+/]',
            icon = 'md_image_search',
            action = act.InputSelector({
               title = 'InputSelector: Select Background',
               choices = backdrops:choices(),
               fuzzy = true,
               fuzzy_description = 'Select Background: ',
               action = wezterm.action_callback(function(win, _p, idx)
                  if not idx then return end
                  ---@diagnostic disable-next-line: param-type-mismatch
                  backdrops:set_img(win, tonumber(idx))
               end),
            }),
         },
         {
            brief = 'Toggle Focus Mode (Hide Background)  [' .. key.S .. '+B]',
            icon = 'md_eye',
            action = wezterm.action_callback(function(win, _p)
               backdrops:toggle_focus(win)
            end),
         },

         -- panes
         {
            brief = 'Split Pane Down  [' .. key.S .. '+\\]',
            icon = 'md_arrow_split_horizontal',
            action = act.SplitPane({ direction = 'Down', size = { Percent = 40 } }),
         },
         {
            brief = 'Split Pane Right  [' .. key.SR .. '+\\]',
            icon = 'md_arrow_split_vertical',
            action = act.SplitPane({ direction = 'Right', size = { Percent = 40 } }),
         },
         {
            brief = 'Toggle Pane Zoom  [' .. key.S .. '+Enter]',
            icon = 'md_arrow_expand_all',
            action = act.TogglePaneZoomState,
         },
         {
            brief = 'Close Pane  [' .. key.S .. '+W]',
            icon = 'md_close',
            action = act.CloseCurrentPane({ confirm = false }),
         },
         {
            brief = 'Swap Pane (Select)  [' .. key.SR .. '+P]',
            icon = 'md_swap_horizontal',
            action = act.PaneSelect({ alphabet = '1234567890', mode = 'SwapWithActiveKeepFocus' }),
         },

         -- scrolling
         {
            brief = 'Jump to Previous Prompt  [Shift+Up]',
            icon = 'md_arrow_up_bold',
            action = act.ScrollToPrompt(-1),
         },
         {
            brief = 'Jump to Next Prompt  [Shift+Down]',
            icon = 'md_arrow_down_bold',
            action = act.ScrollToPrompt(1),
         },

         -- tools
         {
            brief = 'Open File Manager (yazi)  [' .. key.S .. '+E]',
            icon = 'md_folder',
            action = act.SendString('yy\n'),
         },

         -- font
         {
            brief = 'Increase Font Size',
            icon = 'md_format_font_size_increase',
            action = act.IncreaseFontSize,
         },
         {
            brief = 'Decrease Font Size',
            icon = 'md_format_font_size_decrease',
            action = act.DecreaseFontSize,
         },
         {
            brief = 'Reset Font Size',
            icon = 'md_format_size',
            action = act.ResetFontSize,
         },
      }
   end)
end

return M
