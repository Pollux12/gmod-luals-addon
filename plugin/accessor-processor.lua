--[[
	Handles AccessorFunc call processing and generates getter/setter documentation.
--]]

local AccessorProcessor = {}

---Processes AccessorFunc calls in text and generates documentation diffs
---@param text string File content
---@param global string|nil Global scope
---@param class string|nil Class name
---@param config table Configuration
---@return table[] diffs Array of documentation diffs
function AccessorProcessor.processAccessorFuncs(text, global, class, config)
	local diffs = {}
	local patterns = config.patterns or {}
	local accessorPattern = patterns.accessorFunc or "AccessorFunc%s*%("

	-- Find all AccessorFunc calls
	local accessorCalls = AccessorProcessor.findAccessorCalls(text, accessorPattern)

	for _, call in ipairs(accessorCalls) do
		local diff = AccessorProcessor.createAccessorDocumentation(call, global, class, config, text)
		if diff then
			diffs[#diffs + 1] = diff
		end
	end

	return diffs
end

---Finds AccessorFunc calls in text
---@param text string File content
---@param pattern string Search pattern
---@return table[] calls Array of accessor call info
function AccessorProcessor.findAccessorCalls(text, pattern)
	local calls = {}

	for match in text:gmatch(pattern .. "([^%)]*%)") do
		local args = AccessorProcessor.parseAccessorArgs(match)
		if args and args.name then
			calls[#calls + 1] = {
				name = args.name,
				varKey = args.varKey,
				forceType = args.forceType,
				target = args.target,
				position = text:find(pattern .. match, 1, true) or 0
			}
		end
	end

	return calls
end

---Parses AccessorFunc arguments
---@param argsText string Arguments text
---@return table|nil args Parsed arguments
function AccessorProcessor.parseAccessorArgs(argsText)
	-- Parse AccessorFunc(target, varKey, name, forceType)
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
			elseif char == "(" then
				parenDepth = parenDepth + 1
				current = current .. char
			elseif char == ")" then
				parenDepth = parenDepth - 1
				current = current .. char
			elseif char == "," and parenDepth == 0 then
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

	if #parts < 3 then
		return nil
	end

	local target = parts[1]
	local varKey = parts[2]
	local name = parts[3]
	local forceType = parts[4]

	-- Extract string values
	local nameStr = name:match([["([^"]+)"]]) or name:match([['([^']+)']])
	local varKeyStr = varKey:match([["([^"]+)"]]) or varKey:match([['([^']+)']])

	if not nameStr then
		return nil
	end

	return {
		target = target,
		varKey = varKeyStr,
		name = nameStr,
		forceType = forceType
	}
end

---Creates documentation diff for AccessorFunc
---@param call table Accessor call info
---@param global string|nil Global scope
---@param class string|nil Class name
---@param config table Configuration
---@param text string Full file content
---@return table|nil diff Documentation diff
function AccessorProcessor.createAccessorDocumentation(call, global, class, config, text)
	-- Determine the force type
	local forceTypeStr = AccessorProcessor.resolveForceType(call.forceType, config)

	-- Find insertion point (typically before the AccessorFunc call)
	local insertPos = call.position

	-- Generate documentation
	local docs = {}

	-- Add protected backing field if varKey is provided
	if call.varKey then
		docs[#docs + 1] = string.format("---@field protected %s %s", call.varKey, forceTypeStr)
	end

	-- Add getter and setter methods
	local selfType = class or global or "table"
	docs[#docs + 1] = string.format("---@field Set%s fun(self: %s, value: %s)", call.name, selfType, forceTypeStr)
	docs[#docs + 1] = string.format("---@field Get%s fun(self: %s): %s", call.name, selfType, forceTypeStr)

	local docText = table.concat(docs, "\n") .. "\n"

	return {
		start = insertPos - 1,
		finish = insertPos - 1,
		text = docText
	}
end

---Resolves the force type from AccessorFunc argument
---@param forceTypeArg string|nil Force type argument
---@param config table Configuration
---@return string resolvedType
function AccessorProcessor.resolveForceType(forceTypeArg, config)
	if not forceTypeArg then
		return "any"
	end

	-- Check if it's a named constant
	local constantName = forceTypeArg:match("([%a_][%w_]*)")
	if constantName then
		local forceTypes = config.accessorForceTypes or {}
		local resolvedType = forceTypes[constantName]
		if resolvedType then
			return resolvedType
		end
	end

	-- Check if it's a numeric constant
	local numValue = tonumber(forceTypeArg)
	if numValue then
		local numericTypes = {
			[0] = "any", -- FORCE_NONE
			[1] = "string", -- FORCE_STRING
			[2] = "number", -- FORCE_NUMBER
			[3] = "boolean", -- FORCE_BOOL
			[4] = "Angle", -- FORCE_ANGLE
			[5] = "Color", -- FORCE_COLOR
			[6] = "Vector", -- FORCE_VECTOR
		}
		return numericTypes[numValue] or "any"
	end

	return "any"
end

---Checks if text contains AccessorFunc calls
---@param text string File content
---@param patterns table Pattern configurations
---@return boolean hasAccessorFuncs
function AccessorProcessor.hasAccessorFuncs(text, patterns)
	local accessorPattern = patterns.accessorFunc or "AccessorFunc%s*%("
	return text:find(accessorPattern) ~= nil
end

---Processes AccessorFunc calls for a specific target
---@param text string File content
---@param target string Target identifier (e.g., "self", "ENT")
---@param global string|nil Global scope
---@param class string|nil Class name
---@param config table Configuration
---@return table[] diffs Array of documentation diffs
function AccessorProcessor.processAccessorFuncsForTarget(text, target, global, class, config)
	local diffs = {}
	local patterns = config.patterns or {}
	local accessorPattern = patterns.accessorFunc or "AccessorFunc%s*%("

	-- Find AccessorFunc calls that target the specified identifier
	local accessorCalls = AccessorProcessor.findAccessorCalls(text, accessorPattern)

	for _, call in ipairs(accessorCalls) do
		-- Check if this call targets our identifier
		if call.target == target or
			(global and call.target == global) or
			call.target == "self" then
			local diff = AccessorProcessor.createAccessorDocumentation(call, global, class, config, text)
			if diff then
				diffs[#diffs + 1] = diff
			end
		end
	end

	return diffs
end

return AccessorProcessor
