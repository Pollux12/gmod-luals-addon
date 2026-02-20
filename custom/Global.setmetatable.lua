---Sets, changes or removes a table's metatable. Returns Tab (the first argument).
---@realm shared
---@realm menu
---@source https://wiki.facepunch.com/gmod/Global.setmetatable
---@param Tab table The table who's metatable to change.
---@param Metatable? table The metatable to assign. If it's nil, the metatable will be removed.
---@return table # The first argument.
function _G.setmetatable(Tab, Metatable) end
