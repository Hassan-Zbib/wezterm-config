local wezterm = require('wezterm')
local act = wezterm.action
local platform = require('utils.platform')
local actions = require('utils.actions')
local sessions = require('utils.sessions')
local workspaces = require('utils.workspaces')

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
            action = actions.cheatsheet,
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
            brief = 'Workspaces & Sessions  [F5]',
            icon = 'cod_window',
            action = actions.workspace_hub,
         },
         {
            brief = 'Fuzzy Workspace Search',
            icon = 'md_magnify',
            action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }),
         },
         {
            brief = 'New Workspace',
            icon = 'md_plus_box_outline',
            action = wezterm.action_callback(function(win, p)
               workspaces.new_workspace(win, p)
            end),
         },
         {
            brief = 'Rename Workspace',
            icon = 'md_form_textbox',
            action = wezterm.action_callback(function(win, p)
               workspaces.rename_workspace(win, p)
            end),
         },
         {
            brief = 'SSH Host Connect  [F7]',
            icon = 'md_ssh',
            action = actions.ssh_picker,
         },
         {
            brief = 'Copy Mode  [F2]',
            icon = 'md_content_copy',
            action = act.ActivateCopyMode,
         },
         {
            brief = 'Toggle Background Auto-Rotate  [' .. key.S .. '+R]',
            icon = 'md_rotate_right',
            action = actions.toggle_auto_rotate,
         },
         {
            brief = 'Save Session  [F6]',
            icon = 'md_content_save',
            action = actions.save_session,
         },
         {
            brief = 'Save Session (Named)',
            icon = 'md_content_save_edit',
            action = wezterm.action_callback(function(win, p)
               sessions.save_as(win, p)
            end),
         },
         {
            brief = 'Restore Session',
            icon = 'md_backup_restore',
            action = wezterm.action_callback(function(win, p)
               sessions.restore_picker(win, p)
            end),
         },
         {
            brief = 'Restore Session Into Another Workspace',
            icon = 'md_content_duplicate',
            action = wezterm.action_callback(function(win, p)
               sessions.restore_as(win, p)
            end),
         },
         {
            brief = 'Rename Session',
            icon = 'md_rename',
            action = wezterm.action_callback(function(win, p)
               sessions.rename(win, p)
            end),
         },
         {
            brief = 'Delete Session',
            icon = 'md_delete',
            action = wezterm.action_callback(function(win, p)
               sessions.delete(win, p)
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
            action = actions.open_url,
         },

         -- tabs
         {
            brief = 'New Tab  [' .. key.S .. '+T]',
            icon = 'md_tab_plus',
            action = act.SpawnTab('DefaultDomain'),
         },
         {
            brief = 'New WSL Tab  [' .. key.SR .. '+Shift+T]',
            icon = 'linux_tux',
            action = act.SpawnTab({ DomainName = 'WSL:Ubuntu' }),
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
            brief = 'Toggle Tab Bar  [' .. key.SR .. '+9]',
            icon = 'md_eye_off',
            action = act.EmitEvent('tabs.toggle-tab-bar'),
         },

         -- window
         {
            brief = 'New Window  [' .. key.S .. '+N]',
            icon = 'md_window_open',
            action = actions.new_window,
         },

         -- background
         {
            brief = 'Random Background  [' .. key.S .. '+/]',
            icon = 'md_image_multiple',
            action = actions.random_backdrop,
         },
         {
            brief = 'Previous Category  [' .. key.SR .. '+,]',
            icon = 'md_arrow_left',
            action = actions.prev_category,
         },
         {
            brief = 'Next Category  [' .. key.SR .. '+.]',
            icon = 'md_arrow_right',
            action = actions.next_category,
         },
         {
            brief = 'Browse / Cull Backgrounds (Live Preview)  [' .. key.SR .. '+/]',
            icon = 'md_image_search',
            action = actions.browse_backdrops,
         },
         {
            brief = 'Toggle Focus Mode (Hide Background)  [' .. key.S .. '+B]',
            icon = 'md_eye',
            action = actions.toggle_focus,
         },
         {
            brief = 'Toggle Glass in Focus Mode (Acrylic Blur)  [' .. key.SR .. '+B]',
            icon = 'md_blur',
            action = actions.toggle_glass,
         },
         {
            brief = 'Decrease Overlay Opacity / Glass Tint  [' .. key.S .. '+,]',
            icon = 'md_brightness_4',
            action = actions.overlay_opacity_down,
         },
         {
            brief = 'Increase Overlay Opacity / Glass Tint  [' .. key.S .. '+.]',
            icon = 'md_brightness_7',
            action = actions.overlay_opacity_up,
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

         -- tools
         {
            brief = 'Open File Manager (yazi)',
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
