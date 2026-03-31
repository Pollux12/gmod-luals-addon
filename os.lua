---@meta

--- The os library is a standard Lua library originally intended to allow Lua access to various features of the Operating System it's running on, however many of the features and functions have been removed in Garry's Mod due to security issues. It's only used in Garry's Mod for date & time operations.
os = {}

---Returns the approximate cpu time the application ran.
--- See also [Global.SysTime](https://wiki.facepunch.com/gmod/Global.SysTime)
--- **NOTE**: This function has different precision on Linux (1/100).
---@realm shared
---@realm menu
---@source https://wiki.facepunch.com/gmod/os.clock
---@return number # runtime
function os.clock() end

---Returns the date/time as a formatted string or in a table.
---@realm shared
---@realm menu
---@source https://wiki.facepunch.com/gmod/os.date
---@param format? string The format string. If `*t` or `!*t`, returns a [Structures/DateData](https://wiki.facepunch.com/gmod/Structures/DateData) table instead.
---@param time? number Time to use for the format.
---@return string # Formatted date string, or a DateData table if format is `*t` or `!*t`.
function os.date(format, time) end

---Subtracts the second from the first value and rounds the result.
---@realm shared
---@realm menu
---@source https://wiki.facepunch.com/gmod/os.difftime
---@param timeA number The first value.
---@param timeB number The value to subtract.
---@return number # diffTime
function os.difftime(timeA, timeB) end

---Returns the system time in seconds past the unix epoch. If a table is supplied, the function attempts to build a system time with the specified table members.
---@realm shared
---@realm menu
---@source https://wiki.facepunch.com/gmod/os.time
---@param dateData? table Table to generate the time from. This table's data is interpreted as being in the local timezone. See Structures/DateData
---@return number # Seconds passed since Unix epoch
function os.time(dateData) end
