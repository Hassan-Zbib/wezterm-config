---Pane title cleanup shared by the tab pill and the OS window title, so the two
---never disagree about what a pane is called.

local M = {}

---A Windows program that never sets its own title leaves the pane titled after
---its executable, either bare (`delta.exe`) or as a full `C:\...\cmd.exe` path.
---Reduce each such reference to the program name; the rest stays untouched.
---@param title string
---@return string
function M.clean(title)
   local cleaned = title
      :gsub('%a:[/\\][^:]*[/\\]([^/\\]-%.[eE][xX][eE])%f[^%w]', '%1')
      :gsub('%.[eE][xX][eE]%f[^%w]', '')
   return cleaned
end

return M
