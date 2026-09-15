local wezterm = require('wezterm')
local colors = require('colors.custom')

-- Seeding random numbers before generating for use
-- Known issue with lua math library
-- see: https://stackoverflow.com/questions/20154991/generating-uniform-random-numbers-in-lua
math.randomseed(os.time())
math.random()
math.random()
math.random()

local GLOB_PATTERN = '*.{jpg,jpeg,png,gif,bmp,ico,tiff,pnm,dds,tga}'

-- Backdrop legibility. Text paints directly onto the background layers, so
-- readability depends on what the image still carries underneath. Two knobs, in
-- order:
--   1. IMAGE_HSB crushes the image first. `brightness` scales multiplicatively,
--      pulling bright regions (the ones that swallow light text) down further
--      than dark ones, which narrows the contrast spread across a rotating
--      library. `saturation` keeps the image off the syntax colours.
--   2. `overlay_opacity` then flattens the rest under a `focus_color` scrim --
--      the near-black focus mode paints, not the lighter terminal `background`,
--      which reads as a grey wash. Live-adjustable via config/bindings.lua.
local IMAGE_HSB = {
   hue = 1.0,
   saturation = 0.7,
   brightness = 0.8,
}

---@class BackDrops
---@field current_idx number index of current image
---@field images string[] background images
---@field images_dir string directory of background images. Default is `wezterm.config_dir .. '/backdrops/'`
---@field focus_color string background color when in focus mode. Default is `colors.custom.background`
---@field focus_on boolean focus mode on or off
---@field auto_rotate_enabled boolean whether auto-rotation is active
---@field auto_rotate_interval number auto-rotation interval in seconds
---@field _rotate_generation number generation counter to invalidate stale timer chains
local BackDrops = {}
BackDrops.__index = BackDrops

--- Initialise backdrop controller
---@private
function BackDrops:init()
   local inital = {
      current_idx = 1,
      images = {},
      images_dir = wezterm.config_dir .. '/backdrops/',
      focus_color = colors.background,
      focus_on = false,
      auto_rotate_enabled = true,
      -- Each DISTINCT image touched costs a decoded RGBA frame (~18.7MB at
      -- 2880x1620) in WezTerm's uncapped `wezterm-blob-lease-*` cache, only
      -- cleaned on clean exit. At 30s a 12h session writes ~11GB; at 120s,
      -- ~6.7GB. The interval is the only dial.
      auto_rotate_interval = 120,
      _rotate_generation = 0,
      overlay_opacity = 0.85,
      _browse_gen = 0,
      _browse_active = false,
      categories = {},
      current_category = 1,
   }
   local backdrops = setmetatable(inital, self)
   return backdrops
end

---Override the default `images_dir` (`wezterm.config_dir .. '/backdrops/'`).
---Must be called before `set_images()`.
---@param path string directory of background images
function BackDrops:set_images_dir(path)
   self.images_dir = path
   if not path:match('/$') then
      self.images_dir = path .. '/'
   end
   return self
end

---MUST RUN BEFORE ALL OTHER `BackDrops` functions. Each subdirectory becomes a
---category; all images together form "All".
---
---Must be called from `wezterm.lua` during initial config load: it uses
---`wezterm.glob`, which spawns a child process and throws a coroutine error
---anywhere else.
function BackDrops:set_images()
   local flat       = wezterm.glob(self.images_dir .. GLOB_PATTERN)
   local in_subdirs = wezterm.glob(self.images_dir .. '*/' .. GLOB_PATTERN)

   -- Group subdir images by their immediate parent directory name
   local cat_map   = {}
   local cat_order = {}
   for _, img in ipairs(in_subdirs) do
      local rel      = img:sub(#self.images_dir + 1)
      local dir_name = rel:match('^([^/\\]+)[/\\]')
      if dir_name then
         if not cat_map[dir_name] then
            cat_map[dir_name] = {}
            table.insert(cat_order, dir_name)
         end
         table.insert(cat_map[dir_name], img)
      end
   end

   -- "All" category: flat root images only (not subdir images)
   self.categories = {}
   if #flat > 0 then
      table.insert(self.categories, { name = 'All', images = flat })
   end

   -- Per-subdirectory categories
   for _, name in ipairs(cat_order) do
      table.insert(self.categories, { name = name, images = cat_map[name] })
   end

   if #self.categories == 0 then
      self.categories = { { name = 'All', images = {} } }
   end

   self.current_category = 1
   self.images           = self.categories[1].images
   self.current_idx      = #self.images > 0 and math.random(#self.images) or 1

   -- Start auto-rotation timer if enabled by default
   if self.auto_rotate_enabled then
      self._rotate_generation = self._rotate_generation + 1
      self:_schedule_rotate(self._rotate_generation)
   end

   return self
end

---Override the default `focus_color`
---Default `focus_color` is `colors.custom.background`
---@param focus_color string background color when in focus mode
function BackDrops:set_focus(focus_color)
   self.focus_color = focus_color
   return self
end

---Create the `background` options with the current image
---@private
---@return table
function BackDrops:_create_opts()
   return {
      {
         source = { File = self.images[self.current_idx] },
         horizontal_align = 'Center',
         hsb = IMAGE_HSB,
      },
      {
         source = { Color = self.focus_color },
         height = '120%',
         width = '120%',
         vertical_offset = '-10%',
         horizontal_offset = '-10%',
         opacity = self.overlay_opacity,
      },
   }
end

---Create the `background` options for focus mode. Always fully opaque so the
---theme base color paints as a solid background — no DWM backdrop to blend
---against now that Acrylic/Mica are off (incompatible with dGPU rendering).
---@private
---@return table
function BackDrops:_create_focus_opts()
   return {
      {
         source = { Color = self.focus_color },
         height = '120%',
         width = '120%',
         vertical_offset = '-10%',
         horizontal_offset = '-10%',
         opacity = 1.0,
      },
   }
end

---Set the initial options for `background`
---@param focus_on boolean? focus mode on or off
function BackDrops:initial_options(focus_on)
   focus_on = focus_on or false
   assert(type(focus_on) == 'boolean', 'BackDrops:initial_options - Expected a boolean')

   self.focus_on = focus_on
   if focus_on then
      return self:_create_focus_opts()
   end

   return self:_create_opts()
end

---Override the current window options for background.
---The window itself is always fully opaque — the backdrop image and its scrim
---are drawn as background layers, so there is no reason to let the desktop
---bleed through on top of that.
---@private
---@param window any WezTerm Window see: https://wezfurlong.org/wezterm/config/lua/window/index.html
---@param background_opts table background option
function BackDrops:_set_opt(window, background_opts)
   local effective = window:effective_config()
   local override = {
      background = background_opts,
      enable_tab_bar = effective.enable_tab_bar,
      tab_bar_at_bottom = effective.tab_bar_at_bottom,
      window_background_opacity = 1.0,
   }
   -- Memoize per-window: set_config_overrides triggers a config reload that
   -- can disrupt key-table dispatch. Skip the call when nothing changed.
   local img = (background_opts[1] and background_opts[1].source) or {}
   local sig = string.format(
      '%s|%s|%s|%s',
      tostring(img.File or img.Color or ''),
      tostring(self.overlay_opacity),
      tostring(override.enable_tab_bar),
      tostring(override.tab_bar_at_bottom)
   )
   self._last_sig = self._last_sig or {}
   local key = tostring(window:window_id())
   if self._last_sig[key] == sig then return end
   self._last_sig[key] = sig
   window:set_config_overrides(override)
end

---Override the current window options for background with focus color
---@private
---@param window any WezTerm Window see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:_set_focus_opt(window)
   local opts = {
      background = {
         {
            source = { Color = self.focus_color },
            height = '120%',
            width = '120%',
            vertical_offset = '-10%',
            horizontal_offset = '-10%',
            opacity = 1,
         },
      },
      enable_tab_bar = window:effective_config().enable_tab_bar,
      tab_bar_at_bottom = window:effective_config().tab_bar_at_bottom,
   }
   window:set_config_overrides(opts)
end

---Convert the `files` array to a table of `InputSelector` choices
---see: https://wezfurlong.org/wezterm/config/lua/keyassignment/InputSelector.html
function BackDrops:choices()
   local choices = {}
   for idx, file in ipairs(self.images) do
      table.insert(choices, {
         id = tostring(idx),
         label = file:match('([^/]+)$'),
      })
   end
   return choices
end

---Select a random background from the loaded `files`
---Pass in `Window` object to override the current window options
---@param window any? WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:random(window)
   if self.focus_on then return end
   self.current_idx = math.random(#self.images)
   if window ~= nil then
      self:_set_opt(window, self:_create_opts())
   end
end

---Cycle the loaded `files` and select the next background
---@param window any WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:cycle_forward(window)
   if self.focus_on then return end
   if self.current_idx == #self.images then
      self.current_idx = 1
   else
      self.current_idx = self.current_idx + 1
   end
   self:_set_opt(window, self:_create_opts())
end

---Cycle the loaded `files` and select the previous background
---@param window any WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:cycle_back(window)
   if self.focus_on then return end
   if self.current_idx == 1 then
      self.current_idx = #self.images
   else
      self.current_idx = self.current_idx - 1
   end
   self:_set_opt(window, self:_create_opts())
end

---Set a specific background from the `files` array
---@param window any WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
---@param idx number index of the `files` array
function BackDrops:set_img(window, idx)
   if idx > #self.images or idx < 0 then
      wezterm.log_error('Index out of range')
      return
   end

   self.current_idx = idx
   self:_set_opt(window, self:_create_opts())
end

---Switch to the next image category and apply the first image in it.
---Shows a 2-second flash indicator in the status bar.
---@param window any WezTerm Window
function BackDrops:next_category(window)
   if self.focus_on then return end
   self:_exit_browse_if_active(window)
   if #self.categories <= 1 then return end
   self.current_category = self.current_category == #self.categories and 1 or self.current_category + 1
   self.images           = self.categories[self.current_category].images
   if #self.images == 0 then return end
   self.current_idx = math.random(#self.images)
   self:_set_opt(window, self:_create_opts())
end

---Switch to the previous image category and apply the first image in it.
---@param window any WezTerm Window
function BackDrops:prev_category(window)
   if self.focus_on then return end
   self:_exit_browse_if_active(window)
   if #self.categories <= 1 then return end
   self.current_category = self.current_category == 1 and #self.categories or self.current_category - 1
   self.images           = self.categories[self.current_category].images
   if #self.images == 0 then return end
   self.current_idx = math.random(#self.images)
   self:_set_opt(window, self:_create_opts())
end

---Emit update-status immediately on all open windows.
---@private
function BackDrops:_trigger_status_update()
   local gui = wezterm.gui
   if gui then
      for _, win in ipairs(gui.gui_windows()) do
         wezterm.emit('update-status', win, win:active_tab():active_pane())
      end
   end
end

---Toggle auto-rotation. No-ops when focus mode is on.
function BackDrops:toggle_auto_rotate()
   if self.focus_on then return self end
   self:_exit_browse_if_active(nil)
   if self.auto_rotate_enabled then
      self:stop_auto_rotate()
   else
      self:start_auto_rotate()
   end
   self:_trigger_status_update()
   return self
end

---Toggle the focus mode
---When leaving focus mode, always re-enables auto-rotation. When entering, stops it.
---@param window any WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:toggle_focus(window)
   self:_exit_browse_if_active(window)
   local background_opts

   if self.focus_on then
      background_opts = self:_create_opts()
      self.focus_on = false
      if self._auto_rotate_before_focus then
         self:start_auto_rotate()
      end
      self._auto_rotate_before_focus = nil
   else
      self._auto_rotate_before_focus = self.auto_rotate_enabled
      background_opts = self:_create_focus_opts()
      self.focus_on = true
      self:stop_auto_rotate()
   end

   self:_set_opt(window, background_opts)
end

---Schedule the next auto-rotation tick
---@private
---@param gen number generation counter to detect stale timer chains
function BackDrops:_schedule_rotate(gen)
   wezterm.time.call_after(self.auto_rotate_interval, function()
      -- stale chain from a previous start/stop cycle — let it die
      if gen ~= self._rotate_generation then
         return
      end

      -- skip rotation while paused or focused, but keep the chain alive
      if not self.auto_rotate_enabled or self.focus_on then
         self:_schedule_rotate(gen)
         return
      end

      -- skip rotation while any window has a non-default key table active —
      -- a background set_config_overrides during a key-table session can
      -- corrupt keymap dispatch (see the note in events/tab-title.lua).
      local gui = wezterm.gui
      if gui then
         for _, win in ipairs(gui.gui_windows()) do
            if win:active_key_table() ~= nil or win:leader_is_active() then
               self:_schedule_rotate(gen)
               return
            end
         end
      end

      -- cycle forward through the list
      if self.current_idx == #self.images then
         self.current_idx = 1
      else
         self.current_idx = self.current_idx + 1
      end

      -- apply to all open windows
      if gui then
         for _, window in ipairs(gui.gui_windows()) do
            self:_set_opt(window, self:_create_opts())
         end
      end

      self:_schedule_rotate(gen)
   end)
end

---Start auto-rotating backdrops at the given interval
---@param seconds? number rotation interval in seconds (default: 120)
function BackDrops:start_auto_rotate(seconds)
   self.auto_rotate_interval = seconds or 120
   self.auto_rotate_enabled = true
   self._rotate_generation = self._rotate_generation + 1
   self:_schedule_rotate(self._rotate_generation)
   return self
end

---Stop auto-rotating backdrops
function BackDrops:stop_auto_rotate()
   self.auto_rotate_enabled = false
   self._rotate_generation = self._rotate_generation + 1
   return self
end

---Force-exit browse mode: invalidates pending timers and pops the key table
---only when `browse_backdrop` is really on top -- `_browse_active` alone is
---unreliable, since the 30s key-table timeout pops it without calling our exit
---paths. With `window` nil, checks all GUI windows.
---@private
---@param window any? WezTerm Window
function BackDrops:_exit_browse_if_active(window)
   if not self._browse_active then return end
   self._browse_active = false
   self._browse_gen = self._browse_gen + 1
   local function pop_if_browse(win)
      if win:active_key_table() == 'browse_backdrop' then
         win:perform_action(wezterm.action.PopKeyTable, win:active_tab():active_pane())
      end
   end
   if window then
      pop_if_browse(window)
      return
   end
   local gui = wezterm.gui
   if gui then
      for _, win in ipairs(gui.gui_windows()) do
         pop_if_browse(win)
      end
   end
end

---Enter image browse mode: saves current index so it can be reverted on cancel.
---No-ops when focus mode is on or browse mode is already active.
---@param window any WezTerm Window
function BackDrops:enter_browse_mode(window)
   if self.focus_on then return end
   if self._browse_active then return end
   self._browse_active = true
   self._browse_start_idx = self.current_idx
   self._browse_gen = self._browse_gen + 1
   self:_set_opt(window, self:_create_opts())
end

---Shared debounced navigation: updates index immediately, defers image load 150ms.
---@private
local BROWSE_DELAY = 0.15

-- Browse mode doubles as cull mode (see utils/cull.lua), and judging whether an
-- image is actually readable means sitting on it and reading real text for a
-- while. A 30s timeout drops the key table out from under that constantly.
BackDrops.BROWSE_TIMEOUT = 3600000

local function _browse_navigate(self, window, pane)
   self._browse_gen = self._browse_gen + 1
   local gen = self._browse_gen
   -- Keep key table alive immediately (no image load yet)
   window:perform_action(wezterm.action.ActivateKeyTable({
      name = 'browse_backdrop',
      one_shot = false,
      timeout_milliseconds = BackDrops.BROWSE_TIMEOUT,
   }), pane)
   -- Deferred image load — only fires if no newer keypress arrives
   wezterm.time.call_after(BROWSE_DELAY, function()
      if gen ~= self._browse_gen then return end
      self:_set_opt(window, self:_create_opts())
      window:perform_action(wezterm.action.ActivateKeyTable({
         name = 'browse_backdrop',
         one_shot = false,
         timeout_milliseconds = BackDrops.BROWSE_TIMEOUT,
      }), pane)
   end)
end

---Advance to the next image during browse mode.
---@param window any WezTerm Window
---@param pane any WezTerm Pane
function BackDrops:browse_next(window, pane)
   self.current_idx = self.current_idx == #self.images and 1 or self.current_idx + 1
   _browse_navigate(self, window, pane)
end

---Go back to the previous image during browse mode.
---@param window any WezTerm Window
---@param pane any WezTerm Pane
function BackDrops:browse_prev(window, pane)
   self.current_idx = self.current_idx == 1 and #self.images or self.current_idx - 1
   _browse_navigate(self, window, pane)
end

---Confirm browse mode: cancels pending timer, applies current image, exits.
---@param window any WezTerm Window
---@param pane any WezTerm Pane
function BackDrops:browse_confirm(window, pane)
   self._browse_gen = self._browse_gen + 1
   self._browse_active = false
   self:_set_opt(window, self:_create_opts())
   window:perform_action(wezterm.action.PopKeyTable, pane)
end

---Cancel browse mode: revert to the image that was active when browse started.
---@param window any WezTerm Window
---@param pane any WezTerm Pane
function BackDrops:browse_cancel(window, pane)
   self._browse_gen = self._browse_gen + 1
   self._browse_active = false
   self.current_idx = self._browse_start_idx or self.current_idx

   -- Culling during the same browse session shortens `images` underneath us, so
   -- the saved start index can now point past the end -- or at nothing at all if
   -- the whole category went to the bin. Clamp rather than hand `_create_opts` a
   -- nil path.
   if #self.images == 0 then
      self.current_idx = 1
      self:_set_opt(window, self:_create_focus_opts())
      window:perform_action(wezterm.action.PopKeyTable, pane)
      return
   end
   self.current_idx = math.max(1, math.min(self.current_idx, #self.images))

   self:_set_opt(window, self:_create_opts())
   window:perform_action(wezterm.action.PopKeyTable, pane)
end

---Adjust the overlay opacity by a delta and re-apply to the window.
---Clamps between 0.0 and 1.0. No-ops in focus mode.
---@param window any WezTerm Window
---@param delta number positive to increase, negative to decrease
function BackDrops:adjust_overlay_opacity(window, delta)
   if self.focus_on then return end
   self.overlay_opacity = math.floor(math.max(0.0, math.min(1.0, self.overlay_opacity + delta)) * 100 + 0.5) / 100
   self:_set_opt(window, self:_create_opts())
end

return BackDrops:init()
