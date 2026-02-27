---Sets, changes or removes a table's metatable. Returns Tab (the first argument).
---@realm shared
---@realm menu
---@source https://wiki.facepunch.com/gmod/Global.setmetatable
---@generic T: table
---@param table T # The table who's metatable to change.
---@param metatable std.metatable|table|nil # The metatable to assign. If it's nil, the metatable will be removed.
---@return T # Resulting table (first argument).
function _G.setmetatable(table, metatable) end
