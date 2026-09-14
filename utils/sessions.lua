---Workspace session save/restore.
---
---A "session" here is a whole workspace: every window in it, every tab in those
---windows, and the split layout + working directory + domain of every pane.
---
---What is deliberately NOT captured, and why:
---  * scrollback text  -- `pane:inject_output()` only works on local panes, and
---    this config is mux-first (`default_gui_startup_args = {'connect','mux'}`),
---    so replaying output into a restored pane is impossible here.
---  * foreground process -- `get_foreground_process_info()` is documented as
---    local-panes-only, and the mux wire protocol carries no process field at
---    all. It is nil for every pane in this config. Restoring `nvim foo.lua` is
---    therefore not on the table, and neither is *displaying* it in the picker.
---
---Domains ARE captured, so a WSL:Ubuntu tab comes back as WSL:Ubuntu rather
---than as the default shell sitting in a Linux path it cannot reach. Panes of
---different domains inside one tab are supported -- verified against a headless
---mux server, `pane:split{domain=...}` honours a domain different from the
---pane being split.
---
---Storage is one JSON file per session under ~/.config/wezterm/sessions, which
---is a directory `install.conf.yaml` already creates. One file per session
---means a corrupt file costs one session rather than all of them.
local wezterm = require('wezterm')
local act = wezterm.action
local Cells = require('utils.cells')

local M = {}

local SESSIONS_DIR = (wezterm.home_dir .. '/.config/wezterm/sessions'):gsub('\\', '/')
local SCHEMA_VERSION = 2

---How many distinct directory names to show as a hint in the picker.
local MAX_CWD_HINTS = 3

---Workspace name -> session name, remembered from the last save or restore in
---this GUI process. Lost on config reload; `resolve_attached` below recovers
---from the session files themselves, so losing it only costs a prompt.
local attached = {}

-- ---------------------------------------------------------------------------
-- small helpers
-- ---------------------------------------------------------------------------

---@param window table WezTerm Window
---@param title string
---@param message string
local function toast(window, title, message)
   window:toast_notification(title, message, nil, 4000)
end

---Create the sessions directory if it is missing.
local function ensure_dir()
   local win_path = SESSIONS_DIR:gsub('/', '\\')
   wezterm.run_child_process({
      'cmd',
      '/c',
      'if not exist "' .. win_path .. '" mkdir "' .. win_path .. '"',
   })
end

---Fold a user-supplied name into something safe as a Windows filename.
---Strict on purpose: this sidesteps reserved names, trailing dots and every
---illegal character in one rule rather than enumerating them.
---@param name string
---@return string sanitized may be empty, which callers must reject
local function sanitize(name)
   local out = name:gsub('%s+', '-')
   out = out:gsub('[^%w%._%-]', '')
   out = out:gsub('%-+', '-')
   out = out:gsub('^[%-%.]+', ''):gsub('[%-%.]+$', '')
   return out
end

---@param name string
---@return string
local function session_path(name)
   return SESSIONS_DIR .. '/' .. name .. '.json'
end

---Write JSON to a temp file then rename over the target, so an interrupted
---save cannot leave a half-written session behind.
---@param path string
---@param tbl table
---@return boolean ok
---@return string? err
local function write_json(path, tbl)
   ensure_dir()
   local tmp = path .. '.tmp'
   local file, open_err = io.open(tmp, 'w')
   if not file then
      return false, tostring(open_err)
   end

   local ok, encoded = pcall(wezterm.json_encode, tbl)
   if not ok then
      file:close()
      os.remove(tmp)
      return false, 'encode failed: ' .. tostring(encoded)
   end

   file:write(encoded)
   file:close()

   -- os.rename will not overwrite an existing file on Windows.
   os.remove(path)
   local renamed, rename_err = os.rename(tmp, path)
   if not renamed then
      os.remove(tmp)
      return false, tostring(rename_err)
   end
   return true
end

---Read and parse one session file.
---A corrupt file is moved aside rather than silently treated as "no session",
---which is how the previous implementation managed to lose every saved session
---to a single parse error.
---@param path string
---@return table? session
---@return string? err
local function read_json(path)
   local file = io.open(path, 'r')
   if not file then
      return nil, 'not found'
   end
   local content = file:read('*a')
   file:close()

   if content == '' then
      return nil, 'empty file'
   end

   local ok, data = pcall(wezterm.json_parse, content)
   if not ok or type(data) ~= 'table' then
      local aside = path .. '.corrupt-' .. os.date('%Y%m%d-%H%M%S')
      os.rename(path, aside)
      return nil, 'corrupt, moved to ' .. aside
   end
   return data
end

---@return table[] sessions sorted by most recently saved first
local function list_sessions()
   ensure_dir()
   local sessions = {}
   local ok, paths = pcall(wezterm.glob, SESSIONS_DIR .. '/*.json')
   if not ok or not paths then
      return sessions
   end

   for _, path in ipairs(paths) do
      local data = read_json(path)
      if data and data.name then
         table.insert(sessions, data)
      end
   end

   table.sort(sessions, function(a, b)
      return (a.saved_epoch or 0) > (b.saved_epoch or 0)
   end)
   return sessions
end

---@param epoch number?
---@return string
local function relative_time(epoch)
   if not epoch then
      return '?'
   end
   local delta = os.time() - epoch
   if delta < 60 then
      return 'just now'
   elseif delta < 3600 then
      return math.floor(delta / 60) .. 'm ago'
   elseif delta < 86400 then
      return math.floor(delta / 3600) .. 'h ago'
   else
      return math.floor(delta / 86400) .. 'd ago'
   end
end

-- ---------------------------------------------------------------------------
-- paths and domains
-- ---------------------------------------------------------------------------

---@param domain string?
---@return boolean
local function is_wsl_domain(domain)
   return domain ~= nil and domain:match('^WSL:') ~= nil
end

---Turn whatever `get_current_working_dir()` hands back into a path the spawn
---APIs will accept.
---
---Two broken shapes show up on Windows and both have been seen in real saved
---data from the previous implementation:
---   /C:/Users/hassa  -- a Windows path with a slash bolted on, which is what
---                      WezTerm falls back to when a pane never sent OSC 7
---   /c/Users/hassa   -- the MSYS form the zsh/bash/pwsh integrations emit
---Neither is a valid Windows path. WSL panes are left alone: their cwd really
---is a Linux path and rewriting it would break them.
---@param cwd any result of pane:get_current_working_dir()
---@param domain string?
---@return string?
local function normalize_cwd(cwd, domain)
   if not cwd then
      return nil
   end
   local path = type(cwd) == 'table' and (cwd.file_path or tostring(cwd)) or tostring(cwd)
   if path == '' then
      return nil
   end
   if is_wsl_domain(domain) then
      return path
   end
   path = path:gsub('^/(%a):', '%1:')
   path = path:gsub('^/(%a)/', '%1:/')
   return path
end

---@param path string?
---@param domain string?
---@return boolean
local function path_exists(path, domain)
   if not path then
      return false
   end
   -- A Linux path cannot be checked meaningfully from the Windows side; assume
   -- it is fine and let the domain deal with it.
   if is_wsl_domain(domain) then
      return true
   end
   -- `wezterm.glob` on a literal path yields one hit when it exists and none
   -- when it does not, for directories as well as files, and never raises.
   --
   -- Two tempting alternatives are both wrong here. `os.rename(p, p)` -- the
   -- usual Lua existence idiom -- returns "Permission denied" for a directory
   -- that is non-empty or in use, so it reports C:/Users/hassa as missing.
   -- `wezterm.read_dir` works but throws on a missing path, which pcall catches
   -- at the cost of a stack traceback in the log on every absent directory.
   local ok, hits = pcall(wezterm.glob, path)
   if not ok then
      -- Never block a restore on a failed check; let the spawn decide.
      return true
   end
   return hits ~= nil and #hits > 0
end

---@return table<string, boolean>
local function known_domains()
   local names = {}
   local ok, domains = pcall(wezterm.mux.all_domains)
   if ok and domains then
      for _, domain in ipairs(domains) do
         names[domain:name()] = true
      end
   end
   return names
end

-- ---------------------------------------------------------------------------
-- layout tree
-- ---------------------------------------------------------------------------
--
-- WezTerm exposes no split tree -- `panes_with_info()` returns a flat list of
-- rectangles -- so the hierarchy has to be inferred from geometry.
--
-- Every WezTerm layout is a guillotine layout, because every pane is produced
-- by bisecting an existing one. So at each level there must exist a single
-- straight cut, vertical or horizontal, that no pane straddles. Finding that
-- cut is exact.
--
-- The previous implementation instead grouped panes by "smallest left edge",
-- which silently mis-parsed any T-shaped layout: with a full-width pane along
-- the bottom, that pane shares its left edge with the top-left pane and got
-- filed into the left column, so the layout came back wrong.

---@param panes table[]
---@return number minL, number minT, number maxR, number maxB
local function bounds(panes)
   local min_l, min_t = math.huge, math.huge
   local max_r, max_b = -math.huge, -math.huge
   for _, p in ipairs(panes) do
      if p.left < min_l then min_l = p.left end
      if p.top < min_t then min_t = p.top end
      if p.left + p.width > max_r then max_r = p.left + p.width end
      if p.top + p.height > max_b then max_b = p.top + p.height end
   end
   return min_l, min_t, max_r, max_b
end

---Find a straight cut that no pane straddles.
---@param panes table[]
---@param axis 'v'|'h'
---@return table[]? first, table[]? second, number? size fraction for `second`
local function try_cut(panes, axis)
   local min_l, min_t, max_r, max_b = bounds(panes)
   local limit = (axis == 'v') and max_r or max_b
   local origin = (axis == 'v') and min_l or min_t

   local seen, candidates = {}, {}
   for _, p in ipairs(panes) do
      local edge = (axis == 'v') and (p.left + p.width) or (p.top + p.height)
      if edge < limit and not seen[edge] then
         seen[edge] = true
         table.insert(candidates, edge)
      end
   end
   table.sort(candidates)

   for _, cut in ipairs(candidates) do
      local first, second = {}, {}
      local clean = true
      for _, p in ipairs(panes) do
         local lo = (axis == 'v') and p.left or p.top
         local hi = lo + ((axis == 'v') and p.width or p.height)
         if hi <= cut then
            table.insert(first, p)
         elseif lo > cut then
            table.insert(second, p)
         else
            clean = false
            break
         end
      end

      if clean and #first > 0 and #second > 0 then
         local total = limit - origin
         -- The cut line itself is the one-cell divider between the two groups.
         local second_span = limit - cut - 1
         local size = second_span / total
         if size <= 0 or size >= 1 then
            size = 0.5
         end
         return first, second, size
      end
   end
   return nil
end

---@param pane table entry from panes_with_info, already enriched
---@return table leaf
local function leaf_of(pane)
   return {
      type = 'leaf',
      cwd = pane.cwd,
      domain = pane.domain,
      is_active = pane.is_active or false,
      is_zoomed = pane.is_zoomed or false,
   }
end

---@param panes table[]
---@return table node
local function build_tree(panes)
   if #panes == 1 then
      return leaf_of(panes[1])
   end

   local first, second, size = try_cut(panes, 'v')
   local direction = 'Right'
   if not first then
      first, second, size = try_cut(panes, 'h')
      direction = 'Bottom'
   end

   if not first then
      -- Unreachable for any layout WezTerm can produce, but a wrong tree beats
      -- an error: peel one pane off deterministically and carry on.
      wezterm.log_warn('sessions: no guillotine cut found for ' .. #panes .. ' panes')
      table.sort(panes, function(a, b)
         if a.left == b.left then
            return a.top < b.top
         end
         return a.left < b.left
      end)
      local head = table.remove(panes, 1)
      return {
         type = 'split',
         direction = 'Right',
         size = 0.5,
         left = leaf_of(head),
         right = build_tree(panes),
      }
   end

   return {
      type = 'split',
      direction = direction,
      size = size,
      left = build_tree(first),
      right = build_tree(second),
   }
end

---The leaf that a freshly spawned pane will become, so it can be spawned with
---the right cwd and domain immediately rather than corrected afterwards.
---@param node table
---@return table leaf
local function first_leaf(node)
   while node.type == 'split' do
      node = node.left
   end
   return node
end

---@param node table
---@return integer
local function count_leaves(node)
   if node.type == 'leaf' then
      return 1
   end
   return count_leaves(node.left) + count_leaves(node.right)
end

---@param node table
---@param out table[]
local function collect_leaves(node, out)
   if node.type == 'leaf' then
      table.insert(out, node)
      return
   end
   collect_leaves(node.left, out)
   collect_leaves(node.right, out)
end

-- ---------------------------------------------------------------------------
-- capture
-- ---------------------------------------------------------------------------

---@param mux_win table MuxWindow
---@return table window_state
local function capture_window(mux_win)
   local tabs = {}
   local active_tab_idx = 0

   for tab_idx, tab in ipairs(mux_win:tabs()) do
      local panes = {}
      for _, info in ipairs(tab:panes_with_info()) do
         local pane = info.pane
         local domain = pane:get_domain_name()
         table.insert(panes, {
            left = info.left,
            top = info.top,
            width = info.width,
            height = info.height,
            is_active = info.is_active,
            is_zoomed = info.is_zoomed,
            domain = domain,
            cwd = normalize_cwd(pane:get_current_working_dir(), domain),
         })
      end

      if #panes > 0 then
         local active_pane = 0
         for idx, p in ipairs(panes) do
            if p.is_active then
               active_pane = idx - 1
            end
         end

         table.insert(tabs, {
            -- Empty for every tab in this config today, since nothing calls
            -- MuxTab:set_title(). Captured anyway so the feature is correct the
            -- day titles start being set.
            title = tab:get_title() or '',
            active_pane = active_pane,
            tree = build_tree(panes),
         })
      end

      if tab:tab_id() == mux_win:active_tab():tab_id() then
         active_tab_idx = #tabs - 1
      end
   end

   return { active_tab = math.max(active_tab_idx, 0), tabs = tabs }
end

---Capture the whole active workspace.
---@param window table WezTerm Window
---@param name string
---@return table session
local function capture_workspace(window, name)
   local workspace = window:active_workspace()
   local windows = {}

   for _, mux_win in ipairs(wezterm.mux.all_windows()) do
      if mux_win:get_workspace() == workspace then
         local state = capture_window(mux_win)
         if #state.tabs > 0 then
            table.insert(windows, state)
         end
      end
   end

   return {
      version = SCHEMA_VERSION,
      name = name,
      workspace = workspace,
      saved_at = os.date('!%Y-%m-%dT%H:%M:%SZ'),
      saved_epoch = os.time(),
      windows = windows,
   }
end

-- ---------------------------------------------------------------------------
-- restore
-- ---------------------------------------------------------------------------

---@class RestoreCtx
---@field domains table<string, boolean>
---@field missing_cwd string[]
---@field missing_domain string[]

---Build the spawn arguments for a leaf, degrading loudly rather than failing.
---@param leaf table
---@param ctx RestoreCtx
---@return table spawn_args
local function spawn_args_for(leaf, ctx)
   local args = {}

   if leaf.domain and leaf.domain ~= '' then
      if ctx.domains[leaf.domain] then
         args.domain = { DomainName = leaf.domain }
      else
         table.insert(ctx.missing_domain, leaf.domain)
      end
   end

   if leaf.cwd then
      if path_exists(leaf.cwd, leaf.domain) then
         args.cwd = leaf.cwd
      else
         table.insert(ctx.missing_cwd, leaf.cwd)
      end
   end

   return args
end

---Recreate a tab's split layout under `pane`.
---@param pane table the pane occupying this node's area
---@param node table
---@param ctx RestoreCtx
local function restore_tree(pane, node, ctx)
   if node.type == 'leaf' then
      node._pane = pane
      return
   end

   local args = spawn_args_for(first_leaf(node.right), ctx)
   args.direction = node.direction
   args.size = node.size

   local ok, new_pane = pcall(function()
      return pane:split(args)
   end)

   if not ok or not new_pane then
      wezterm.log_error('sessions: split failed: ' .. tostring(new_pane))
      -- Keep whatever was rebuilt so far rather than aborting the restore.
      restore_tree(pane, node.left, ctx)
      return
   end

   restore_tree(pane, node.left, ctx)
   restore_tree(new_pane, node.right, ctx)
end

---@param tab table MuxTab
---@param tab_state table
local function apply_tab_state(tab, tab_state)
   if tab_state.title and tab_state.title ~= '' then
      tab:set_title(tab_state.title)
   end

   local leaves = {}
   collect_leaves(tab_state.tree, leaves)

   local zoomed = nil
   local active = nil
   for idx, leaf in ipairs(leaves) do
      if leaf._pane then
         if leaf.is_zoomed then
            zoomed = leaf._pane
         end
         if leaf.is_active or (tab_state.active_pane and idx - 1 == tab_state.active_pane) then
            active = leaf._pane
         end
      end
      leaf._pane = nil
   end

   if active then
      active:activate()
   end
   if zoomed then
      zoomed:activate()
      tab:set_zoomed(true)
   end
end

---@param session table
---@param target_workspace string
---@param ctx RestoreCtx
---@return integer windows_restored
local function restore_windows(session, target_workspace, ctx)
   local restored = 0

   for _, window_state in ipairs(session.windows or {}) do
      local first_tab_state = window_state.tabs[1]
      if first_tab_state then
         local args = spawn_args_for(first_leaf(first_tab_state.tree), ctx)
         args.workspace = target_workspace

         local ok, tab, pane, mux_win = pcall(function()
            local t, p, w = wezterm.mux.spawn_window(args)
            return t, p, w
         end)

         if ok and mux_win then
            restore_tree(pane, first_tab_state.tree, ctx)
            apply_tab_state(tab, first_tab_state)

            for idx = 2, #window_state.tabs do
               local tab_state = window_state.tabs[idx]
               local tab_args = spawn_args_for(first_leaf(tab_state.tree), ctx)
               local tab_ok, new_tab, new_pane = pcall(function()
                  local t, p = mux_win:spawn_tab(tab_args)
                  return t, p
               end)
               if tab_ok and new_tab then
                  restore_tree(new_pane, tab_state.tree, ctx)
                  apply_tab_state(new_tab, tab_state)
               else
                  wezterm.log_error('sessions: spawn_tab failed: ' .. tostring(new_tab))
               end
            end

            local tabs = mux_win:tabs()
            local want = (window_state.active_tab or 0) + 1
            if tabs[want] then
               tabs[want]:activate()
            end
            restored = restored + 1
         else
            wezterm.log_error('sessions: spawn_window failed: ' .. tostring(tab))
         end
      end
   end

   return restored
end

---@param window table WezTerm Window
---@param ctx RestoreCtx
local function report_degradation(window, ctx)
   local notes = {}
   if #ctx.missing_cwd > 0 then
      table.insert(notes, #ctx.missing_cwd .. ' missing path(s): ' .. table.concat(ctx.missing_cwd, ', '))
   end
   if #ctx.missing_domain > 0 then
      table.insert(notes, 'unknown domain(s): ' .. table.concat(ctx.missing_domain, ', '))
   end
   if #notes > 0 then
      toast(window, 'Session Restored With Warnings', table.concat(notes, ' | '))
   end
end

-- ---------------------------------------------------------------------------
-- workspace helpers
-- ---------------------------------------------------------------------------

---@param workspace string
---@return boolean
local function workspace_is_live(workspace)
   for _, mux_win in ipairs(wezterm.mux.all_windows()) do
      if mux_win:get_workspace() == workspace then
         return true
      end
   end
   return false
end

-- ---------------------------------------------------------------------------
-- public API
-- ---------------------------------------------------------------------------

---Build InputSelector choices for the saved sessions.
---@return table[]
function M.choices()
   local choices = {}

   for _, session in ipairs(list_sessions()) do
      local tab_count, pane_count = 0, 0
      local seen_dirs, dirs = {}, {}

      for _, window_state in ipairs(session.windows or {}) do
         for _, tab_state in ipairs(window_state.tabs or {}) do
            tab_count = tab_count + 1
            pane_count = pane_count + count_leaves(tab_state.tree)

            local leaves = {}
            collect_leaves(tab_state.tree, leaves)
            for _, leaf in ipairs(leaves) do
               if leaf.cwd and #dirs < MAX_CWD_HINTS then
                  local base = leaf.cwd:gsub('[/\\]+$', ''):match('([^/\\]+)$')
                  if base and not seen_dirs[base] then
                     seen_dirs[base] = true
                     table.insert(dirs, base)
                  end
               end
            end
         end
      end

      local cells = Cells:new()
      cells:add_segment('name', ' ' .. session.name .. ' ', nil, { Cells.attr.intensity('Bold') })
      cells:add_segment('workspace', ' ' .. (session.workspace or '?'), nil, { Cells.attr.intensity('Half') })
      cells:add_segment(
         'counts',
         '  ' .. tab_count .. ' tabs · ' .. pane_count .. ' panes',
         nil,
         { Cells.attr.intensity('Half') }
      )

      local ids = { 'name', 'workspace', 'counts' }
      if #dirs > 0 then
         cells:add_segment('dirs', '  ' .. table.concat(dirs, ', '), nil, { Cells.attr.intensity('Half') })
         table.insert(ids, 'dirs')
      end
      cells:add_segment('age', '  ' .. relative_time(session.saved_epoch), nil, { Cells.attr.intensity('Half') })
      table.insert(ids, 'age')

      table.insert(choices, {
         id = session.name,
         label = wezterm.format(cells:render(ids)),
      })
   end

   return choices
end

---Write the active workspace to `name`, overwriting whatever is there.
---@param window table WezTerm Window
---@param name string already sanitized
local function write_session(window, name)
   local session = capture_workspace(window, name)
   local tab_count = 0
   for _, window_state in ipairs(session.windows) do
      tab_count = tab_count + #window_state.tabs
   end

   if tab_count == 0 then
      toast(window, 'Session Not Saved', 'Nothing to capture in this workspace.')
      return
   end

   local ok, err = write_json(session_path(name), session)
   if not ok then
      toast(window, 'Session Save Failed', tostring(err))
      return
   end

   attached[session.workspace] = name
   toast(
      window,
      'Session Saved',
      string.format('"%s" — %d window(s), %d tab(s)', name, #session.windows, tab_count)
   )
end

---Prompt for a name, then save.
---@param window table WezTerm Window
---@param pane table WezTerm Pane
---@param default string
local function prompt_and_save(window, pane, default)
   window:perform_action(
      act.PromptInputLine({
         description = 'Save session as (default: ' .. default .. '):',
         action = wezterm.action_callback(function(win, prompt_pane, line)
            if line == nil then
               return
            end
            local name = sanitize(line ~= '' and line or default)
            if name == '' then
               toast(win, 'Session Not Saved', 'That name has no usable characters.')
               return
            end

            if read_json(session_path(name)) then
               win:perform_action(
                  act.InputSelector({
                     title = 'Overwrite "' .. name .. '"?',
                     choices = {
                        { id = 'no', label = 'Cancel' },
                        { id = 'yes', label = 'Overwrite' },
                     },
                     action = wezterm.action_callback(function(inner_win, _ip, id)
                        if id == 'yes' then
                           write_session(inner_win, name)
                        end
                     end),
                  }),
                  prompt_pane
               )
            else
               write_session(win, name)
            end
         end),
      }),
      pane
   )
end

---Which session does this workspace belong to?
---Falls back to scanning the session files when the in-memory link was lost to
---a config reload, so a bare save stays one keystroke across restarts.
---@param workspace string
---@return string? name
---@return table[] candidates when the answer is ambiguous
local function resolve_attached(workspace)
   if attached[workspace] and read_json(session_path(attached[workspace])) then
      return attached[workspace], {}
   end

   local matches = {}
   for _, session in ipairs(list_sessions()) do
      if session.workspace == workspace then
         table.insert(matches, session)
      end
   end

   if #matches == 1 then
      return matches[1].name, {}
   end
   return nil, matches
end

---Name of the session this workspace would save over, if that is unambiguous.
---Used by the hub to label the Save action with what it will actually do.
---@param workspace string
---@return string? name
function M.attached_name(workspace)
   local name = resolve_attached(workspace)
   return name
end

---Reveal the sessions directory in the OS file manager.
function M.open_folder()
   ensure_dir()
   wezterm.open_with(SESSIONS_DIR:gsub('/', '\\'))
end

---Quick save: update the session this workspace is attached to, prompting only
---when there is nothing to update or the choice is ambiguous.
---@param window table WezTerm Window
---@param pane table WezTerm Pane
function M.save(window, pane)
   local workspace = window:active_workspace()
   local name, candidates = resolve_attached(workspace)

   if name then
      write_session(window, name)
      return
   end

   if #candidates > 1 then
      local choices = {}
      for _, session in ipairs(candidates) do
         table.insert(choices, { id = session.name, label = session.name })
      end
      table.insert(choices, { id = '', label = 'Save as new…' })

      window:perform_action(
         act.InputSelector({
            title = 'Update which session?',
            choices = choices,
            fuzzy = true,
            fuzzy_description = 'Update session: ',
            action = wezterm.action_callback(function(win, p, id)
               if id == nil then
                  return
               end
               if id == '' then
                  prompt_and_save(win, p, workspace)
               else
                  write_session(win, id)
               end
            end),
         }),
         pane
      )
      return
   end

   prompt_and_save(window, pane, workspace)
end

---Always prompt for a new name.
---@param window table WezTerm Window
---@param pane table WezTerm Pane
function M.save_as(window, pane)
   prompt_and_save(window, pane, window:active_workspace())
end

---Restore a session into a workspace.
---@param window table WezTerm Window
---@param pane table WezTerm Pane
---@param name string
---@param target_workspace string?
function M.restore(window, pane, name, target_workspace)
   local session, err = read_json(session_path(name))
   if not session then
      toast(window, 'Session Restore Failed', '"' .. name .. '": ' .. tostring(err))
      return
   end

   local workspace = target_workspace or session.workspace or 'default'

   local function go()
      local ctx = { domains = known_domains(), missing_cwd = {}, missing_domain = {} }
      local restored = restore_windows(session, workspace, ctx)

      window:perform_action(act.SwitchToWorkspace({ name = workspace }), pane)
      toast(
         window,
         'Session Restored',
         string.format('"%s" — %d window(s) in workspace "%s"', name, restored, workspace)
      )
      report_degradation(window, ctx)
   end

   if not workspace_is_live(workspace) then
      go()
      return
   end

   -- No "close the existing windows first" option: WezTerm's Lua API has no way
   -- to kill a pane, tab or window (confirmed against the Pane and MuxWindow
   -- method lists), so a replace action could only be faked. Close unwanted
   -- tabs by hand with Alt+Ctrl+W and restore again.
   window:perform_action(
      act.InputSelector({
         title = 'Workspace "' .. workspace .. '" is already open',
         choices = {
            { id = 'new', label = 'Restore into a new window' },
            { id = 'cancel', label = 'Cancel' },
         },
         action = wezterm.action_callback(function(_win, _p, id)
            if id == 'new' then
               go()
            end
         end),
      }),
      pane
   )
end

---@param window table WezTerm Window
---@param pane table WezTerm Pane
---@param prompt string
---@param on_pick fun(win: table, pane: table, name: string)
local function pick_session(window, pane, prompt, on_pick)
   local choices = M.choices()
   if #choices == 0 then
      toast(window, 'No Sessions', 'Nothing saved yet — use Save first.')
      return
   end

   window:perform_action(
      act.InputSelector({
         title = prompt,
         choices = choices,
         fuzzy = true,
         fuzzy_description = prompt .. ': ',
         action = wezterm.action_callback(function(win, p, id)
            if id then
               on_pick(win, p, id)
            end
         end),
      }),
      pane
   )
end

---Pick a session and restore it into the workspace it was saved from.
---@param window table WezTerm Window
---@param pane table WezTerm Pane
function M.restore_picker(window, pane)
   pick_session(window, pane, 'Restore Session', function(win, p, name)
      M.restore(win, p, name)
   end)
end

---@param window table WezTerm Window
---@param pane table WezTerm Pane
function M.delete(window, pane)
   pick_session(window, pane, 'Delete Session', function(win, p, name)
      win:perform_action(
         act.InputSelector({
            title = 'Delete "' .. name .. '"?',
            choices = {
               { id = 'no', label = 'Cancel' },
               { id = 'yes', label = 'Delete' },
            },
            action = wezterm.action_callback(function(inner_win, _ip, id)
               if id == 'yes' then
                  os.remove(session_path(name))
                  for workspace, attached_name in pairs(attached) do
                     if attached_name == name then
                        attached[workspace] = nil
                     end
                  end
                  toast(inner_win, 'Session Deleted', '"' .. name .. '"')
               end
            end),
         }),
         p
      )
   end)
end

---@param window table WezTerm Window
---@param pane table WezTerm Pane
function M.rename(window, pane)
   pick_session(window, pane, 'Rename Session', function(win, p, name)
      win:perform_action(
         act.PromptInputLine({
            description = 'Rename "' .. name .. '" to:',
            action = wezterm.action_callback(function(inner_win, _ip, line)
               if line == nil or line == '' then
                  return
               end
               local new_name = sanitize(line)
               if new_name == '' then
                  toast(inner_win, 'Rename Failed', 'That name has no usable characters.')
                  return
               end
               if new_name == name then
                  return
               end
               if read_json(session_path(new_name)) then
                  toast(inner_win, 'Rename Failed', '"' .. new_name .. '" already exists.')
                  return
               end

               local session = read_json(session_path(name))
               if not session then
                  toast(inner_win, 'Rename Failed', 'Could not read "' .. name .. '".')
                  return
               end
               session.name = new_name

               local ok, err = write_json(session_path(new_name), session)
               if not ok then
                  toast(inner_win, 'Rename Failed', tostring(err))
                  return
               end
               os.remove(session_path(name))
               for workspace, attached_name in pairs(attached) do
                  if attached_name == name then
                     attached[workspace] = new_name
                  end
               end
               toast(inner_win, 'Session Renamed', name .. ' → ' .. new_name)
            end),
         }),
         p
      )
   end)
end

---Restore into a workspace other than the one the session was saved from,
---leaving the original untouched. Turns a session into a reusable template.
---@param window table WezTerm Window
---@param pane table WezTerm Pane
function M.restore_as(window, pane)
   pick_session(window, pane, 'Restore Session As', function(win, p, name)
      local session = read_json(session_path(name))
      local default = session and session.workspace or name
      win:perform_action(
         act.PromptInputLine({
            description = 'Restore "' .. name .. '" into workspace:',
            action = wezterm.action_callback(function(inner_win, inner_pane, line)
               if line == nil or line == '' then
                  return
               end
               M.restore(inner_win, inner_pane, name, line)
            end),
         }),
         p
      )
   end)
end

-- There is deliberately no session-only manager menu here any more. Sessions
-- and workspaces are the same concept at two lifetimes, so the single entry
-- point is `utils/workspaces.lua`'s hub on F5, which drives the functions
-- above. F9 still quick-saves without opening anything.

return M
