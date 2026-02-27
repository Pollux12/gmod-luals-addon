---Gets the value with the specified key from the table without calling the __index method.
---@realm shared
---@realm menu
---@source https://wiki.facepunch.com/gmod/Global.rawget
---@generic T, K
---@param table T # Table to get the value from.
---@param index std.ConstTpl<K> # The index to get the value from.
---@return std.RawGet<T, K> # The value.
function _G.rawget(table, index) end