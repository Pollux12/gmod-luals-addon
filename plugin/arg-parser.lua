--[[
	Shared argument parsing utilities for function call processing.

	Provides consistent argument splitting logic for AccessorFunc, NetworkVar, and similar calls.
	Handles string literals, escape sequences, and nested parentheses correctly.
--]]

local ArgParser = {}

---Splits function arguments text into individual argument parts
---@param argsText string Arguments text (e.g., '"Type", 1, "Name"')
---@param options table|nil Options {trackParentheses: boolean}
---@return string[] parts Array of trimmed argument parts
function ArgParser.splitArguments(argsText, options)
	options = options or {}
	local trackParentheses = options.trackParentheses or false

	local parts = {}
	local current = ""
	local inString = false
	local stringChar = nil
	local parenDepth = 0

	for i = 1, #argsText do
		local char = argsText:sub(i, i)

		if not inString then
			if char == '"' or char == "'" then
				inString = true
				stringChar = char
				current = current .. char
			elseif trackParentheses and char == "(" then
				parenDepth = parenDepth + 1
				current = current .. char
			elseif trackParentheses and char == ")" then
				parenDepth = parenDepth - 1
				current = current .. char
			elseif char == "," and (not trackParentheses or parenDepth == 0) then
				parts[#parts + 1] = current:match("^%s*(.-)%s*$") -- trim
				current = ""
			else
				current = current .. char
			end
		else
			current = current .. char
			if char == stringChar and argsText:sub(i - 1, i - 1) ~= "\\" then
				inString = false
				stringChar = nil
			end
		end
	end

	if current ~= "" then
		parts[#parts + 1] = current:match("^%s*(.-)%s*$") -- trim
	end

	return parts
end

---Extracts string value from quoted argument
---@param arg string Argument part (e.g., '"Hello"' or "'World'")
---@return string|nil stringValue Extracted string value or nil if not a string
function ArgParser.extractStringValue(arg)
	return arg:match([["([^"]+)"]]) or arg:match([['([^']+)']])
end

---Extracts numeric value from argument
---@param arg string Argument part (e.g., "123" or " 456 ")
---@return number|nil numValue Extracted numeric value or nil if not a number
function ArgParser.extractNumericValue(arg)
	local trimmed = arg:match("^%s*(.-)%s*$")
	return tonumber(trimmed)
end

-- Credit to: https://github.com/JanSharp/LuaArgParser

local isWindows = package.config:sub(1, 1) == "\\"

local function percentDecode(str)
	return (str:gsub("%%(%x%x)", function(h)
		return string.char(tonumber(h, 16))
	end))
end

local function normaliseIdentity(value)
	if type(value) ~= "string" then
		return nil
	end
	local result = value
	if result:match("^file://") then
		result = result:sub(8)
		result = percentDecode(result)
		if result:match("^/[A-Za-z]:") then
			result = result:sub(2)
		end
	else
		result = percentDecode(result)
	end
	result = result:gsub("\\+", "/")
	if isWindows then
		result = result:lower()
	end
	return result
end

local function isArrayTable(tbl)
	if type(tbl) ~= "table" then
		return false
	end
	for k in pairs(tbl) do
		if type(k) ~= "number" then
			return false
		end
	end
	return true
end

local function tokenizeCommandLine(text)
	local tokens = {}
	if type(text) ~= "string" or text == "" then
		return tokens
	end

	local i, len = 1, #text
	while i <= len do
		while i <= len and text:sub(i, i):match("%s") do
			i = i + 1
		end
		if i > len then break end

		local ch = text:sub(i, i)
		local token
		if ch == '"' or ch == "'" then
			local quote = ch
			i = i + 1
			local buffer = {}
			local escaping = false
			while i <= len do
				local c = text:sub(i, i)
				if escaping then
					buffer[#buffer + 1] = c
					escaping = false
				elseif c == "\\" then
					escaping = true
				elseif c == quote then
					i = i + 1
					break
				else
					buffer[#buffer + 1] = c
				end
				i = i + 1
			end
			token = table.concat(buffer)
		else
			local start = i
			while i <= len and not text:sub(i, i):match("%s") do
				i = i + 1
			end
			token = text:sub(start, i - 1)
		end

		if token and token ~= "" then
			tokens[#tokens + 1] = token
		end
	end

	return tokens
end

local function coerceArgsSequence(raw)
	if type(raw) ~= "table" then
		return nil
	end
	if not isArrayTable(raw) then
		return nil
	end
	local result = {}
	local max = #raw
	for i = 1, max do
		local value = raw[i]
		if value ~= nil then
			if type(value) ~= "string" then
				value = tostring(value)
			end
			result[#result + 1] = value
		end
	end
	return result
end

local function flattenPluginArgs(raw, identity)
	local rawType = type(raw)
	if rawType == "string" then
		return tokenizeCommandLine(raw)
	elseif rawType == "table" then
		local direct = coerceArgsSequence(raw)
		if direct then
			return direct
		end
		local fallback
		for key, value in pairs(raw) do
			if fallback == nil then
				fallback = value
			end
			if identity and type(key) == "string" then
				local kNorm = normaliseIdentity(key)
				if kNorm == identity then
					return flattenPluginArgs(value, identity)
				end
			end
		end
		if fallback ~= nil then
			return flattenPluginArgs(fallback, identity)
		end
	end
	return nil
end

local function parseCommandLineArgs(args)
	local options = {}
	local extras = {}
	if not args then
		return options, extras
	end

	local i = 1
	while i <= #args do
		local current = args[i]
		if type(current) ~= "string" then
			current = tostring(current)
		end
		if current == "--no-workspace-config" then
			options.disableWorkspaceConfig = true
			i = i + 1
		elseif current:match("^%-%-config=") then
			local value = current:match("^%-%-config=(.*)$") or ""
			if value ~= "" then
				options.configPath = value
			else
				extras[#extras + 1] = current
			end
			i = i + 1
		elseif current == "--config" then
			local nextValue = args[i + 1]
			if type(nextValue) == "string" and nextValue ~= "" then
				options.configPath = nextValue
				i = i + 2
			else
				extras[#extras + 1] = current
				i = i + 1
			end
		else
			extras[#extras + 1] = current
			i = i + 1
		end
	end

	return options, extras
end

function ArgParser.normalizePluginIdentity(value)
	return normaliseIdentity(value)
end

function ArgParser.normalizePluginArgs(rawArgs, pluginIdentity)
	local identity = normaliseIdentity(pluginIdentity)
	return flattenPluginArgs(rawArgs, identity)
end

function ArgParser.parsePluginCommandLine(args)
	return parseCommandLineArgs(args)
end

function ArgParser.parsePluginOptions(rawArgs, pluginIdentity)
	local args = ArgParser.normalizePluginArgs(rawArgs, pluginIdentity)
	local opts, extras = parseCommandLineArgs(args)
	return opts or {}, extras or {}
end

return ArgParser
