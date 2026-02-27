---Returns a string representing the name of the type of the passed object.
--- **WARNING**: This will return `table` if the input is [Global.Color](https://wiki.facepunch.com/gmod/Global.Color), consider using [Global.IsColor](https://wiki.facepunch.com/gmod/Global.IsColor) in that case.
---@realm shared
---@realm menu
---@source https://wiki.facepunch.com/gmod/Global.type
---@param var any
---@return std.type type
function _G.type(var) end