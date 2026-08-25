------------------------------------------------------------------------------------------
-- Inspired by https://github.com/wez/wezterm/discussions/628#discussioncomment-1874614 --
------------------------------------------------------------------------------------------

local wezterm = require('wezterm')
local Cells = require('utils.cells')
local p = require('colors.palette')
local OptsValidator = require('utils.opts-validator')

---
-- =======================================
-- Defining event setup options and schema
-- =======================================

---@alias Event.TabTitleOptions { unseen_icon: 'circle' | 'numbered_circle' | 'numbered_box', hide_active_tab_unseen: boolean }

---Setup options for the tab title
local EVENT_OPTS = {}

---@type OptsSchema
EVENT_OPTS.schema = {
   {
      name = 'unseen_icon',
      type = 'string',
      enum = { 'circle', 'numbered_circle', 'numbered_box' },
      default = 'circle',
   },
   {
      name = 'hide_active_tab_unseen',
      type = 'boolean',
      default = true,
   },
}
EVENT_OPTS.validator = OptsValidator:new(EVENT_OPTS.schema)

---
-- ===================
-- Constants and icons
-- ===================

local nf = wezterm.nerdfonts

local M = {}

local GLYPH_SCIRCLE_LEFT = '' --[[  ]]
local GLYPH_SCIRCLE_RIGHT = '' --[[  ]]
local GLYPH_BELL = nf.md_bell_ring
local GLYPH_CIRCLE = nf.fa_circle --[[  ]]
local GLYPH_ADMIN = nf.md_shield_half_full --[[ 󰞀 ]]
local GLYPH_LINUX = nf.cod_terminal_linux --[[  ]]
local GLYPH_DEBUG = nf.fa_bug --[[  ]]
-- local GLYPH_SEARCH = nf.fa_search --[[  ]]
local GLYPH_SEARCH = '🔭'

local GLYPH_UNSEEN_NUMBERED_BOX = {
   [1] = nf.md_numeric_1_box_multiple, --[[ 󰼏 ]]
   [2] = nf.md_numeric_2_box_multiple, --[[ 󰼐 ]]
   [3] = nf.md_numeric_3_box_multiple, --[[ 󰼑 ]]
   [4] = nf.md_numeric_4_box_multiple, --[[ 󰼒 ]]
   [5] = nf.md_numeric_5_box_multiple, --[[ 󰼓 ]]
   [6] = nf.md_numeric_6_box_multiple, --[[ 󰼔 ]]
   [7] = nf.md_numeric_7_box_multiple, --[[ 󰼕 ]]
   [8] = nf.md_numeric_8_box_multiple, --[[ 󰼖 ]]
   [9] = nf.md_numeric_9_box_multiple, --[[ 󰼗 ]]
   [10] = nf.md_numeric_9_plus_box_multiple, --[[ 󰼘 ]]
}

local GLYPH_UNSEEN_NUMBERED_CIRCLE = {
   [1] = nf.md_numeric_1_circle, --[[ 󰲠 ]]
   [2] = nf.md_numeric_2_circle, --[[ 󰲢 ]]
   [3] = nf.md_numeric_3_circle, --[[ 󰲤 ]]
   [4] = nf.md_numeric_4_circle, --[[ 󰲦 ]]
   [5] = nf.md_numeric_5_circle, --[[ 󰲨 ]]
   [6] = nf.md_numeric_6_circle, --[[ 󰲪 ]]
   [7] = nf.md_numeric_7_circle, --[[ 󰲬 ]]
   [8] = nf.md_numeric_8_circle, --[[ 󰲮 ]]
   [9] = nf.md_numeric_9_circle, --[[ 󰲰 ]]
   [10] = nf.md_numeric_9_plus_circle, --[[ 󰲲 ]]
}

local TITLE_INSET = {
   DEFAULT = 6,
   ICON = 8,
}

-- Panes that have rung the bell since their tab was last focused, keyed by
-- pane id. Populated by the `bell` event, drained when the owning tab becomes
-- active. Agent CLIs ring the bell when they finish or need a decision, so this
-- is what makes a backgrounded agent tab announce itself.
---@type table<number, boolean>
local bell_panes = {}


-- Inactive tabs are light-on-dark (subtext1 over surface1/2); the active tab
-- inverts to dark-on-sapphire so it reads as the selected pill. The `scircle_*`
-- entries are the pill end-caps, so their fg must match the corresponding
-- text bg.
---@type table<string, Cells.SegmentColors>
-- stylua: ignore
local colors = {
   text_default          = { bg = p.surface1, fg = p.subtext1 },
   text_hover            = { bg = p.surface2, fg = p.text },
   text_active           = { bg = p.sapphire, fg = p.crust },

   unseen_output_default = { bg = p.surface1, fg = p.peach },
   unseen_output_hover   = { bg = p.surface2, fg = p.peach },
   -- Peach on sapphire is near-invisible; the active pill needs a dark marker.
   unseen_output_active  = { bg = p.sapphire, fg = p.crust },

   -- Red, so a tab waiting on you is distinguishable at a glance from a tab
   -- that merely produced output (peach).
   bell_default          = { bg = p.surface1, fg = p.red },
   bell_hover            = { bg = p.surface2, fg = p.red },
   bell_active           = { bg = p.sapphire, fg = p.crust },

   scircle_default       = { bg = p.ui.status_bg, fg = p.surface1 },
   scircle_hover         = { bg = p.ui.status_bg, fg = p.surface2 },
   scircle_active        = { bg = p.ui.status_bg, fg = p.sapphire },
}

---
-- ================
-- Helper functions
-- ================

---@param proc string
local function clean_process_name(proc)
   local a = string.gsub(proc, '(.*[/\\])(.*)', '%2')
   return a:gsub('%.exe$', '')
end

---@param process_name string
---@param base_title string
---@param max_width number
---@param inset number
local function create_title(process_name, base_title, max_width, inset)
   local title

   if process_name:len() > 0 then
      title = process_name .. ' ~ ' .. base_title
   else
      title = base_title
   end

   if base_title == 'Debug' then
      title = GLYPH_DEBUG .. ' DEBUG'
      inset = inset - 2
   end

   if base_title:match('^InputSelector:') ~= nil then
      title = base_title:gsub('InputSelector:', GLYPH_SEARCH)
      inset = inset - 2
   end

   local title_width = wezterm.column_width(title)
   local available = math.max(0, max_width - inset)

   if title_width > available then
      title = available > 0 and wezterm.truncate_right(title, available) or ''
   else
      local padding = available - title_width
      title = title .. string.rep(' ', padding)
   end

   return title
end

---@param panes any[] WezTerm https://wezfurlong.org/wezterm/config/lua/pane/index.html
local function check_unseen_output(panes)
   local unseen_output = false
   local unseen_output_count = 0

   for i = 1, #panes, 1 do
      if panes[i].has_unseen_output then
         unseen_output = true
         if unseen_output_count >= 10 then
            unseen_output_count = 10
            break
         end
         unseen_output_count = unseen_output_count + 1
      end
   end

   return unseen_output, unseen_output_count
end

---
-- =================
-- Tab class and API
-- =================

---@class Tab
---@field title string
---@field cells FormatCells
---@field title_locked boolean
---@field locked_title string
---@field is_wsl boolean
---@field is_admin boolean
---@field unseen_output boolean
---@field unseen_output_count number
---@field has_bell boolean
---@field is_active boolean
local Tab = {}
Tab.__index = Tab

function Tab:new()
   local tab = {
      title = '',
      cells = Cells:new(),
      title_locked = false,
      locked_title = '',
      is_wsl = false,
      is_admin = false,
      unseen_output = false,
      unseen_output_count = 0,
      has_bell = false,
   }
   return setmetatable(tab, self)
end

---@param event_opts Event.TabTitleOptions
---@param tab any WezTerm https://wezfurlong.org/wezterm/config/lua/MuxTab/index.html
---@param max_width number
function Tab:set_info(event_opts, tab, max_width)
   local process_name = clean_process_name(tab.active_pane.foreground_process_name)

   self.is_wsl = process_name:match('^wsl') ~= nil
   self.is_admin = (
      tab.active_pane.title:match('^Administrator: ') or tab.active_pane.title:match('(Admin)')
   ) ~= nil
   self.unseen_output = false
   self.unseen_output_count = 0

   if not event_opts.hide_active_tab_unseen or not tab.is_active then
      self.unseen_output, self.unseen_output_count = check_unseen_output(tab.panes)
   end

   -- Focusing a tab is the acknowledgement — drop the bell for every pane it
   -- owns. Otherwise surface a bell if any pane in the tab rang one.
   self.has_bell = false
   for _, pane in ipairs(tab.panes) do
      if tab.is_active then
         bell_panes[pane.pane_id] = nil
      elseif bell_panes[pane.pane_id] then
         self.has_bell = true
      end
   end

   local inset = (self.is_admin or self.is_wsl) and TITLE_INSET.ICON or TITLE_INSET.DEFAULT
   if self.unseen_output then
      inset = inset + 2
   end
   if self.has_bell then
      inset = inset + 2
   end

   -- show pane indicator when tab has multiple panes
   local pane_count = #tab.panes
   local pane_suffix = ''
   if pane_count > 1 then
      for i, p in ipairs(tab.panes) do
         if p.is_active then
            pane_suffix = ' [' .. i .. '/' .. pane_count .. ']'
            break
         end
      end
      inset = inset + #pane_suffix
   end

   if self.title_locked then
      self.title = create_title('', self.locked_title, max_width, inset) .. pane_suffix
      return
   end
   self.title = create_title(process_name, tab.active_pane.title, max_width, inset) .. pane_suffix
end

function Tab:create_cells()
   local attr = self.cells.attr
   self.cells
      :add_segment('scircle_left', GLYPH_SCIRCLE_LEFT)
      :add_segment('admin', ' ' .. GLYPH_ADMIN)
      :add_segment('wsl', ' ' .. GLYPH_LINUX)
      :add_segment('title', ' ', nil, attr(attr.intensity('Bold')))
      :add_segment('bell', ' ' .. GLYPH_BELL, nil, attr(attr.intensity('Bold')))
      :add_segment('unseen_output', ' ' .. GLYPH_CIRCLE)
      :add_segment('padding', ' ')
      :add_segment('scircle_right', GLYPH_SCIRCLE_RIGHT)
end

---@param title string
function Tab:update_and_lock_title(title)
   self.locked_title = title
   self.title_locked = true
end

---@param event_opts Event.TabTitleOptions
---@param is_active boolean
---@param hover boolean
function Tab:update_cells(event_opts, is_active, hover)
   local tab_state = 'default'
   if is_active then
      tab_state = 'active'
   elseif hover then
      tab_state = 'hover'
   end

   self.cells:update_segment_text('title', ' ' .. self.title)

   if event_opts.unseen_icon == 'numbered_box' and self.unseen_output then
      self.cells:update_segment_text(
         'unseen_output',
         ' ' .. GLYPH_UNSEEN_NUMBERED_BOX[self.unseen_output_count]
      )
   end
   if event_opts.unseen_icon == 'numbered_circle' and self.unseen_output then
      self.cells:update_segment_text(
         'unseen_output',
         ' ' .. GLYPH_UNSEEN_NUMBERED_CIRCLE[self.unseen_output_count]
      )
   end

   -- Cache the last-applied tab_state. Skip the eight update_segment_colors
   -- calls when nothing changed — format-tab-title fires many times per render
   -- and stacking that work on top of focus mode's set_config_overrides was
   -- causing keymap dispatch issues.
   if self._last_state == tab_state then
      return
   end
   self._last_state = tab_state

   self.cells
      :update_segment_colors('scircle_left', colors['scircle_' .. tab_state])
      :update_segment_colors('admin', colors['text_' .. tab_state])
      :update_segment_colors('wsl', colors['text_' .. tab_state])
      :update_segment_colors('title', colors['text_' .. tab_state])
      :update_segment_colors('bell', colors['bell_' .. tab_state])
      :update_segment_colors('unseen_output', colors['unseen_output_' .. tab_state])
      :update_segment_colors('padding', colors['text_' .. tab_state])
      :update_segment_colors('scircle_right', colors['scircle_' .. tab_state])
end

---Assemble the pill left-to-right. Replaces a fixed variant table that would
---have needed twelve entries once the bell indicator was added.
---@return FormatItem[] (ref: https://wezfurlong.org/wezterm/config/lua/wezterm/format.html)
function Tab:render()
   local ids = { 'scircle_left' }

   -- WSL wins over admin when both match, matching the previous variant table.
   if self.is_wsl then
      table.insert(ids, 'wsl')
   elseif self.is_admin then
      table.insert(ids, 'admin')
   end

   table.insert(ids, 'title')
   if self.has_bell then
      table.insert(ids, 'bell')
   end
   if self.unseen_output then
      table.insert(ids, 'unseen_output')
   end
   table.insert(ids, 'padding')
   table.insert(ids, 'scircle_right')

   return self.cells:render(ids)
end

---@type Tab[]
local tab_list = {}

---@param opts? Event.TabTitleOptions Default: {unseen_icon = 'circle', hide_active_tab_unseen = true}
M.setup = function(opts)
   local valid_opts, err = EVENT_OPTS.validator:validate(opts or {})

   if err then
      wezterm.log_error(err)
   end

   -- BUILTIN EVENT
   -- Mark the ringing pane. The tab it belongs to is resolved at render time
   -- from `tab.panes`, so there is no pane -> tab lookup to keep in sync, and a
   -- pane that is closed while still flagged simply stops being iterated over.
   wezterm.on('bell', function(_window, pane)
      bell_panes[pane:pane_id()] = true
   end)

   -- CUSTOM EVENT
   -- Event listener to manually update the tab name
   -- Tab name will remain locked until the `reset-tab-title` is triggered
   wezterm.on('tabs.manual-update-tab-title', function(window, pane)
      window:perform_action(
         wezterm.action.PromptInputLine({
            description = wezterm.format({
               { Foreground = { Color = p.text } },
               { Attribute = { Intensity = 'Bold' } },
               { Text = 'Enter new name for tab' },
            }),
            action = wezterm.action_callback(function(_window, _pane, line)
               if line ~= nil then
                  local tab = window:active_tab()
                  local id = tab:tab_id()
                  tab_list[id]:update_and_lock_title(line)
               end
            end),
         }),
         pane
      )
   end)

   -- CUSTOM EVENT
   -- Event listener to unlock manually set tab name
   wezterm.on('tabs.reset-tab-title', function(window, _pane)
      local tab = window:active_tab()
      local id = tab:tab_id()
      tab_list[id].title_locked = false
   end)

   -- CUSTOM EVENT
   -- Event listener to manually update the tab name
   wezterm.on('tabs.toggle-tab-bar', function(window, _pane)
      local effective_config = window:effective_config()
      window:set_config_overrides({
         enable_tab_bar = not effective_config.enable_tab_bar,
         background = effective_config.background,
      })
   end)

   -- CUSTOM EVENT
   -- Flip tab bar position (top <-> bottom). Window buttons follow the bar.
   wezterm.on('tabs.toggle-tab-bar-position', function(window, _pane)
      local effective_config = window:effective_config()
      local new_pos = not effective_config.tab_bar_at_bottom
      window:set_config_overrides({
         tab_bar_at_bottom = new_pos,
         background = effective_config.background,
         enable_tab_bar = effective_config.enable_tab_bar,
      })
   end)

   -- BUILTIN EVENT
   wezterm.on('format-tab-title', function(tab, _tabs, _panes, _config, hover, max_width)
      if not tab_list[tab.tab_id] then
         tab_list[tab.tab_id] = Tab:new()
         tab_list[tab.tab_id]:set_info(valid_opts, tab, max_width)
         tab_list[tab.tab_id]:create_cells()
         return tab_list[tab.tab_id]:render()
      end

      tab_list[tab.tab_id]:set_info(valid_opts, tab, max_width)
      tab_list[tab.tab_id]:update_cells(valid_opts, tab.is_active, hover)
      return tab_list[tab.tab_id]:render()
   end)
end

return M
