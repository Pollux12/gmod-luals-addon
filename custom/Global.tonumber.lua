---Attempts to convert the value to a number. The value can be a string, a number, or any object with a `__tonumber` metamethod.
--- Can also convert numbers from other [numerical bases](https://www.mathsisfun.com/numbers/bases.html) to base 10.
---@realm shared
---@realm menu
---@source https://wiki.facepunch.com/gmod/Global.tonumber
---@param value any The value to be converted.
---@param base? number The numerical base of the digits in the input value.
--- Must be an integer between `2` and `36` (inclusive)
---@return number|nil # The base `10` number representation of the input value, or `nil` if the conversion failed.
function _G.tonumber(value, base) end
