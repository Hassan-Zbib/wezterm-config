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
      auto_rotate_interval = 30,
      _rotate_generation = 0,
      overlay_opacity = 0.90,
      _browse_gen = 0,
      categories = {},
      current_category = 1,
      _category_flash_until = 0,
      _rotate_flash_until = 0,
      _overlay_flash_until = 0,
   }
   local backdrops = setmetatable(inital, self)
   return backdrops
end

---Override the default `images_dir`
---Default `images_dir` is `wezterm.config_dir .. '/backdrops/'`
---
--- INFO:
---  This function must be invoked before `set_images()`
---
---@param path string directory of background images
function BackDrops:set_images_dir(path)
   self.images_dir = path
   if not path:match('/$') then
      self.images_dir = path .. '/'
   end
   return self
end

---MUST BE RUN BEFORE ALL OTHER `BackDrops` functions
---Sets the `images` after instantiating `BackDrops`.
---Automatically detects subdirectories as categories.
---Each subdirectory becomes its own category; all images combined form the "All" category.
---
--- INFO:
---   During the initial load of the config, this function can only invoked in `wezterm.lua`.
---   WezTerm's fs utility `glob` (used in this function) works by running on a spawned child process.
---   This throws a coroutine error if the function is invoked in outside of `wezterm.lua` in the -
---   initial load of the Terminal config.
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
      },
      {
         source = { Color = colors.background },
         height = '120%',
         width = '120%',
         vertical_offset = '-10%',
         horizontal_offset = '-10%',
         opacity = self.overlay_opacity,
      },
   }
end

---Create the `background` options for focus mode
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
         opacity = 1,
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

---Override the current window options for background
---@private
---@param window any WezTerm Window see: https://wezfurlong.org/wezterm/config/lua/window/index.html
---@param background_opts table background option
function BackDrops:_set_opt(window, background_opts)
   window:set_config_overrides({
      background = background_opts,
      enable_tab_bar = window:effective_config().enable_tab_bar,
   })
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
   if #self.categories <= 1 then return end
   self.current_category = self.current_category == #self.categories and 1 or self.current_category + 1
   self.images           = self.categories[self.current_category].images
   if #self.images == 0 then return end
   self.current_idx              = math.random(#self.images)
   self._category_flash_until    = os.time() + 2
   self:_set_opt(window, self:_create_opts())
   self:_schedule_status_flash()
end

---Switch to the previous image category and apply the first image in it.
---Shows a 2-second flash indicator in the status bar.
---@param window any WezTerm Window
function BackDrops:prev_category(window)
   if self.focus_on then return end
   if #self.categories <= 1 then return end
   self.current_category = self.current_category == 1 and #self.categories or self.current_category - 1
   self.images           = self.categories[self.current_category].images
   if #self.images == 0 then return end
   self.current_idx              = math.random(#self.images)
   self._category_flash_until    = os.time() + 2
   self:_set_opt(window, self:_create_opts())
   self:_schedule_status_flash()
end

---Schedule a forced status bar update after the flash duration expires.
---@private
function BackDrops:_schedule_status_flash()
   wezterm.time.call_after(2.1, function()
      local gui = wezterm.gui
      if gui then
         for _, win in ipairs(gui.gui_windows()) do
            wezterm.emit('update-status', win, win:active_tab():active_pane())
         end
      end
   end)
end

---Return a display string for the category flash indicator, or nil if expired or focus mode is on.
---@return string|nil
function BackDrops:category_indicator()
   if self.focus_on then return nil end
   if os.time() >= self._category_flash_until then return nil end
   local cat = self.categories[self.current_category]
   if not cat then return nil end
   return string.format('%s  (%d/%d)', cat.name, self.current_category, #self.categories)
end

---Return 'ON' or 'OFF' during the rotate flash window, or nil if expired or focus mode is on.
---@return string|nil
function BackDrops:rotate_indicator()
   if self.focus_on then return nil end
   if os.time() >= self._rotate_flash_until then return nil end
   return self.auto_rotate_enabled and 'ON' or 'OFF'
end

---Return an opacity string during the overlay flash window, or nil if expired or focus mode is on.
---@return string|nil
function BackDrops:overlay_indicator()
   if self.focus_on then return nil end
   if os.time() >= self._overlay_flash_until then return nil end
   return string.format('%.0f%%', self.overlay_opacity * 100)
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

---Toggle auto-rotation and show a momentary status bar indicator.
---No-ops when focus mode is on.
function BackDrops:toggle_auto_rotate()
   if self.focus_on then return self end
   if self.auto_rotate_enabled then
      self:stop_auto_rotate()
   else
      self:start_auto_rotate()
   end
   self._rotate_flash_until = os.time() + 2
   self:_trigger_status_update()
   self:_schedule_status_flash()
   return self
end

---Toggle the focus mode
---When leaving focus mode, always re-enables auto-rotation. When entering, stops it.
---@param window any WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:toggle_focus(window)
   local background_opts

   if self.focus_on then
      background_opts = self:_create_opts()
      self.focus_on = false
      self:start_auto_rotate()
   else
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

      -- cycle forward through the list
      if self.current_idx == #self.images then
         self.current_idx = 1
      else
         self.current_idx = self.current_idx + 1
      end

      -- apply to all open windows
      local gui = wezterm.gui
      if gui then
         for _, window in ipairs(gui.gui_windows()) do
            self:_set_opt(window, self:_create_opts())
         end
      end

      self:_schedule_rotate(gen)
   end)
end

---Start auto-rotating backdrops at the given interval
---@param seconds? number rotation interval in seconds (default: 30)
function BackDrops:start_auto_rotate(seconds)
   self.auto_rotate_interval = seconds or 30
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

---Enter image browse mode: saves current index so it can be reverted on cancel.
---No-ops when focus mode is on.
---@param window any WezTerm Window
function BackDrops:enter_browse_mode(window)
   if self.focus_on then return end
   self._browse_start_idx = self.current_idx
   self._browse_gen = self._browse_gen + 1
   self:_set_opt(window, self:_create_opts())
end

---Shared debounced navigation: updates index immediately, defers image load 150ms.
---@private
local BROWSE_DELAY = 0.15
local function _browse_navigate(self, window, pane)
   self._browse_gen = self._browse_gen + 1
   local gen = self._browse_gen
   -- Keep key table alive immediately (no image load yet)
   window:perform_action(wezterm.action.ActivateKeyTable({
      name = 'browse_backdrop',
      one_shot = false,
      timeout_milliseconds = 30000,
   }), pane)
   -- Deferred image load — only fires if no newer keypress arrives
   wezterm.time.call_after(BROWSE_DELAY, function()
      if gen ~= self._browse_gen then return end
      self:_set_opt(window, self:_create_opts())
      window:perform_action(wezterm.action.ActivateKeyTable({
         name = 'browse_backdrop',
         one_shot = false,
         timeout_milliseconds = 30000,
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
   self:_set_opt(window, self:_create_opts())
   window:perform_action(wezterm.action.PopKeyTable, pane)
end

---Cancel browse mode: revert to the image that was active when browse started.
---@param window any WezTerm Window
---@param pane any WezTerm Pane
function BackDrops:browse_cancel(window, pane)
   self._browse_gen = self._browse_gen + 1
   self.current_idx = self._browse_start_idx or self.current_idx
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
   self._overlay_flash_until = os.time() + 2
   self:_set_opt(window, self:_create_opts())
   self:_schedule_status_flash()
end

return BackDrops:init()
