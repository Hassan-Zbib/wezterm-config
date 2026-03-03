local wezterm = require('wezterm')
local Cells = require('utils.cells')

local M = {}

---Parse ~/.ssh/config and return a list of host entries
---@return table[] list of {alias, hostname, user}
local function parse_ssh_config()
   local ssh_config = wezterm.home_dir .. '/.ssh/config'
   local file = io.open(ssh_config, 'r')
   if not file then
      return {}
   end

   local hosts = {}
   local current = nil

   for line in file:lines() do
      line = line:gsub('%s+$', '')
      local host = line:match('^%s*Host%s+(.+)$')
      if host then
         -- Skip wildcard and github entries
         if not host:match('^%*') and not host:match('github%.com') then
            current = { alias = host, hostname = nil, user = nil }
            table.insert(hosts, current)
         else
            current = nil
         end
      elseif current then
         local hostname = line:match('^%s*[Hh]ost[Nn]ame%s+(.+)$')
         if hostname then
            current.hostname = hostname
         end
         local user = line:match('^%s*[Uu]ser%s+(.+)$')
         if user then
            current.user = user
         end
      end
   end

   file:close()
   return hosts
end

---Build InputSelector choices from SSH config
---@return table[]
function M.choices()
   local hosts = parse_ssh_config()
   local choices = {}

   for _, host in ipairs(hosts) do
      local cells = Cells:new()
      cells:add_segment('name', ' ' .. host.alias .. ' ', nil, { Cells.attr.intensity('Bold') })

      local detail = ''
      if host.user and host.hostname then
         detail = host.user .. '@' .. host.hostname
      elseif host.hostname then
         detail = host.hostname
      elseif host.user then
         detail = host.user .. '@' .. host.alias
      end

      if detail ~= '' then
         cells:add_segment('detail', ' ' .. detail, nil, { Cells.attr.intensity('Half') })
      end

      table.insert(choices, {
         id = host.alias,
         label = wezterm.format(cells:render({ 'name', 'detail' })),
      })
   end

   return choices
end

---Connect to an SSH host by alias in the current pane
---@param pane table WezTerm Pane
---@param host_alias string
function M.connect(pane, host_alias)
   pane:send_text('ssh ' .. host_alias .. '\n')
end

return M
