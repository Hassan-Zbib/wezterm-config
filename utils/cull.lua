-- Backdrop culling -- the delete half of browse mode (Alt+Ctrl+/).
--
-- This is not a mode of its own. Browse mode already walks the active category
-- one image at a time with the real IMAGE_HSB crush, the real scrim, and your
-- real terminal content behind it; that is exactly the view you need to judge
-- whether an image is pleasant *and* readable. Culling just adds a verdict to
-- that walk, so it lives in the same key table rather than a parallel one.
--
-- A cull is a two-stage delete. `d` does an `os.rename` into a staging dir,
-- which is instant and trivially reversible with `u`. Only when browse mode
-- exits does the accumulated batch go to the Recycle Bin, in a single detached
-- PowerShell call. So undo is free during the session, and Explorer is the undo
-- after it. `backdrops/` is gitignored, so the Recycle Bin is the only safety
-- net there is -- hence never unlinking directly.
--
-- The staging dir deliberately lives OUTSIDE `backdrops/` -- `set_images()`
-- promotes every subdirectory to a category, so a quarantine folder in there
-- would show up in the rotation.

local wezterm = require('wezterm')
local backdrops = require('utils.backdrops')

local WORK_DIR = wezterm.home_dir .. '/.wezterm-backdrop-cull'
local STAGE_DIR = WORK_DIR .. '/staged'
local FLUSH_FILE = WORK_DIR .. '/flush.txt'

-- Matches the browse-mode debounce: holding a key shouldn't decode every image
-- it skims past.
local NAV_DELAY = 0.15

---@class Cull
---@field _undo table[] stack of `{ path, staged, idx }` for in-session undo
---@field _pending string[] staged files awaiting the Recycle Bin flush
---@field _dirs table<string, boolean> staging dirs already created this session
---@field _binned number culls in the current browse session
local Cull = {}
Cull.__index = Cull

---@private
function Cull:init()
   return setmetatable({ _undo = {}, _pending = {}, _dirs = {}, _binned = 0 }, self)
end

---@private
local function win_path(path)
   return (path:gsub('/', '\\'))
end

---`mkdir` creates intermediates and errors harmlessly when the dir exists.
---@private
local function mkdir(path)
   wezterm.run_child_process({ 'cmd.exe', '/c', 'mkdir', win_path(path) })
end

---@private
local function write_file(path, data)
   local f = io.open(path, 'wb')
   if not f then return false end
   f:write(data)
   f:close()
   return true
end

---Staging dir for the active category, created on first use. Resolved per cull
---rather than up front because browse mode can be entered from any category.
---@private
function Cull:_stage_dir()
   local cat = backdrops.categories[backdrops.current_category]
   local dir = STAGE_DIR .. '/' .. (cat and cat.name or 'All')
   if not self._dirs[dir] then
      mkdir(dir)
      self._dirs[dir] = true
   end
   return dir
end

---Re-arm the browse key table. Every action does this so the table survives both
---the keypress itself and the deferred image load.
---@private
function Cull:_arm(window, pane)
   window:perform_action(
      wezterm.action.ActivateKeyTable({
         name = 'browse_backdrop',
         one_shot = false,
         timeout_milliseconds = backdrops.BROWSE_TIMEOUT,
      }),
      pane
   )
end

---Debounced render of the current index. Shares `_browse_gen` with browse
---navigation so a pending nav load and a pending cull load cancel each other.
---@private
function Cull:_show(window, pane)
   backdrops._browse_gen = backdrops._browse_gen + 1
   local gen = backdrops._browse_gen
   self:_arm(window, pane)
   wezterm.time.call_after(NAV_DELAY, function()
      if gen ~= backdrops._browse_gen then return end
      if #backdrops.images == 0 then
         backdrops:_set_opt(window, backdrops:_create_focus_opts())
         return
      end
      backdrops:_set_opt(window, backdrops:_create_opts())
      self:_arm(window, pane)
   end)
end

---Start a fresh cull history. Called when browse mode opens.
---
---Also flushes any batch orphaned by an exit path that bypasses `finish()` --
---a category switch, a focus-mode toggle, or the key-table timeout all pop the
---table via `_exit_browse_if_active` without going through confirm/cancel.
---Undo for that batch is gone by then anyway, so binning it here is the right
---outcome rather than leaving files stranded in staging.
function Cull:begin()
   self:_flush()
   self._undo = {}
   self._binned = 0
end

---Stage the current image for deletion and advance. Removing it from
---`backdrops.images` also removes it from the category table -- they are the
---same table reference -- so it leaves the rotation immediately.
---@param window any WezTerm Window
---@param pane any WezTerm Pane
function Cull:cull(window, pane)
   local images = backdrops.images
   local idx = backdrops.current_idx
   local path = images[idx]
   if not path then return end

   local name = path:match('([^/\\]+)$')
   local staged = self:_stage_dir() .. '/' .. name
   local ok, err = os.rename(path, staged)
   if not ok then
      window:toast_notification('Backdrops', 'Could not stage ' .. name .. ': ' .. tostring(err), nil, 5000)
      return
   end

   table.remove(images, idx)
   table.insert(self._undo, { path = path, staged = staged, idx = idx })
   table.insert(self._pending, staged)
   self._binned = self._binned + 1

   -- After the removal, `idx` already points at the next image.
   backdrops.current_idx = (#images == 0 or idx > #images) and 1 or idx
   self:_show(window, pane)
end

---Undo the most recent cull. Only available until browse mode exits and the
---batch is flushed to the Recycle Bin.
---@param window any WezTerm Window
---@param pane any WezTerm Pane
function Cull:undo(window, pane)
   local last = table.remove(self._undo)
   if not last then return end

   local ok, err = os.rename(last.staged, last.path)
   if not ok then
      window:toast_notification('Backdrops', 'Could not restore: ' .. tostring(err), nil, 5000)
      table.insert(self._undo, last)
      return
   end

   for i = #self._pending, 1, -1 do
      if self._pending[i] == last.staged then
         table.remove(self._pending, i)
         break
      end
   end

   table.insert(backdrops.images, last.idx, last.path)
   backdrops.current_idx = last.idx
   self._binned = self._binned - 1
   self:_show(window, pane)
end

---Send every staged file to the Recycle Bin in one detached PowerShell call --
---detached so a few hundred shell calls never stall the GUI thread. Paths go
---through a UTF-8 list file rather than the command line to keep non-ASCII
---filenames and quoting intact.
---@private
function Cull:_flush()
   if #self._pending == 0 then return end
   write_file(FLUSH_FILE, table.concat(self._pending, '\r\n') .. '\r\n')

   local ps = table.concat({
      'Add-Type -AssemblyName Microsoft.VisualBasic;',
      "Get-Content -LiteralPath '" .. FLUSH_FILE .. "' -Encoding UTF8 |",
      "Where-Object { $_.Trim() -ne '' } |",
      'ForEach-Object {',
      "[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($_.Trim(),'OnlyErrorDialogs','SendToRecycleBin')",
      '}',
   }, ' ')
   local args = { 'powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', ps }

   local ok = pcall(wezterm.background_child_process, args)
   if not ok then
      pcall(wezterm.run_child_process, args)
   end
   self._pending = {}
end

---Commit the session: flush the staged batch to the Recycle Bin. Called after
---browse mode confirms or cancels -- both exits commit, since a cull is a
---verdict on the image itself, not on which wallpaper you happened to pick.
---@param window any WezTerm Window
function Cull:finish(window)
   local binned = self._binned
   self._binned = 0
   self._undo = {}
   self:_flush()

   if binned > 0 then
      window:toast_notification(
         'Backdrops',
         string.format('%d sent to the Recycle Bin. %d left in this category.', binned, #backdrops.images),
         nil,
         5000
      )
   end
end

return Cull:init()
