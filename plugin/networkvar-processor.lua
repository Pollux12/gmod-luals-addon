--[[
	Handles NetworkVar and NetworkVarElement call processing and generates getter/setter documentation.
--]]

local NetworkVarProcessor = {}

---Processes NetworkVar calls in text and generates documentation diffs
---@param text string File content
---@param global string|nil Global scope
---@param class string|nil Class name
---@param config table Configuration
---@return table[] diffs Array of documentation diffs
function NetworkVarProcessor.processNetworkVars(text, global, class, config)
	local diffs = {}

	-- Process NetworkVar calls
	local networkVarDiffs = NetworkVarProcessor.processNetworkVarCalls(text, global, class, config)
	for _, diff in ipairs(networkVarDiffs) do
		diffs[#diffs + 1] = diff
	end

	-- Process NetworkVarElement calls
	local networkVarElementDiffs = NetworkVarProcessor.processNetworkVarElementCalls(text, global, class, config)
	for _, diff in ipairs(networkVarElementDiffs) do
		diffs[#diffs + 1] = diff
	end

	return diffs
end

---Processes NetworkVar calls in text
---@param text string File content
---@param global string|nil Global scope
---@param class string|nil Class name
---@param config table Configuration
---@return table[] diffs Array of documentation diffs
function NetworkVarProcessor.processNetworkVarCalls(text, global, class, config)
	local diffs = {}
	local patterns = config.patterns or {}
	local networkVarPattern = patterns.networkVar or "NetworkVar%s*%("

	-- Find all NetworkVar calls
	local networkVarCalls = NetworkVarProcessor.findNetworkVarCalls(text, networkVarPattern)

	for _, call in ipairs(networkVarCalls) do
		local diff = NetworkVarProcessor.createNetworkVarDocumentation(call, global, class, config, text)
		if diff then
			diffs[#diffs + 1] = diff
		end
	end

	return diffs
end

---Processes NetworkVarElement calls in text
---@param text string File content
---@param global string|nil Global scope
---@param class string|nil Class name
---@param config table Configuration
---@return table[] diffs Array of documentation diffs
function NetworkVarProcessor.processNetworkVarElementCalls(text, global, class, config)
	local diffs = {}
	local patterns = config.patterns or {}
	local networkVarElementPattern = patterns.networkVarElement or "NetworkVarElement%s*%("

	-- Find all NetworkVarElement calls
	local networkVarElementCalls = NetworkVarProcessor.findNetworkVarElementCalls(text, networkVarElementPattern)

	for _, call in ipairs(networkVarElementCalls) do
		local diff = NetworkVarProcessor.createNetworkVarElementDocumentation(call, global, class, config, text)
		if diff then
			diffs[#diffs + 1] = diff
		end
	end

	return diffs
end

---Finds NetworkVar calls in text
---@param text string File content
---@param pattern string Search pattern
---@return table[] calls Array of NetworkVar call info
function NetworkVarProcessor.findNetworkVarCalls(text, pattern)
	local calls = {}

	for match in text:gmatch(pattern .. "([^%)]*%)") do
		local args = NetworkVarProcessor.parseNetworkVarArgs(match)
		if args and args.type and args.name then
			calls[#calls + 1] = {
				type = args.type,
				name = args.name,
				position = text:find(pattern .. match, 1, true) or 0
			}
		end
	end

	return calls
end

---Finds NetworkVarElement calls in text
---@param text string File content
---@param pattern string Search pattern
---@return table[] calls Array of NetworkVarElement call info
function NetworkVarProcessor.findNetworkVarElementCalls(text, pattern)
	local calls = {}

	for match in text:gmatch(pattern .. "([^%)]*%)") do
		local args = NetworkVarProcessor.parseNetworkVarElementArgs(match)
		if args and args.type and args.name then
			calls[#calls + 1] = {
				type = args.type,
				name = args.name,
				index = args.index,
				position = text:find(pattern .. match, 1, true) or 0
			}
		end
	end

	return calls
end

---Parses NetworkVar arguments
---@param argsText string Arguments text
---@return table|nil args Parsed arguments
function NetworkVarProcessor.parseNetworkVarArgs(argsText)
	-- Parse NetworkVar("Type", "Name")
	local parts = {}
	local current = ""
	local inString = false
	local stringChar = nil

	for i = 1, #argsText do
		local char = argsText:sub(i, i)

		if not inString then
			if char == '"' or char == "'" then
				inString = true
				stringChar = char
				current = current .. char
			elseif char == "," then
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

	if #parts < 2 then
		return nil
	end

	local typeStr = parts[1]:match([["([^"]+)"]]) or parts[1]:match([['([^']+)']])
	local nameStr = parts[2]:match([["([^"]+)"]]) or parts[2]:match([['([^']+)']])

	if not typeStr or not nameStr then
		return nil
	end

	return {
		type = typeStr,
		name = nameStr
	}
end

---Parses NetworkVarElement arguments
---@param argsText string Arguments text
---@return table|nil args Parsed arguments
function NetworkVarProcessor.parseNetworkVarElementArgs(argsText)
	-- Parse NetworkVarElement("Type", index, "Name")
	local parts = {}
	local current = ""
	local inString = false
	local stringChar = nil

	for i = 1, #argsText do
		local char = argsText:sub(i, i)

		if not inString then
			if char == '"' or char == "'" then
				inString = true
				stringChar = char
				current = current .. char
			elseif char == "," then
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

	local typeStr = parts[1]:match([["([^"]+)"]]) or parts[1]:match([['([^']+)']])
	local indexStr = parts[2]:match("^%s*(%d+)%s*$")
	local nameStr = parts[3]:match([["([^"]+)"]]) or parts[3]:match([['([^']+)']])

	if not typeStr or not nameStr then
		return nil
	end

	return {
		type = typeStr,
		name = nameStr,
		index = indexStr and tonumber(indexStr) or nil
	}
end

---Creates documentation diff for NetworkVar
---@param call table NetworkVar call info
---@param global string|nil Global scope
---@param class string|nil Class name
---@param config table Configuration
---@param text string Full file content
---@return table|nil diff Documentation diff
function NetworkVarProcessor.createNetworkVarDocumentation(call, global, class, config, text)
	-- Resolve the data type
	local luaType = NetworkVarProcessor.resolveDtType(call.type, config)

	-- Find insertion point
	local insertPos = call.position

	-- Generate documentation
	local selfType = class or global or "Entity"
	local docs = {
		string.format("---@field Set%s fun(self: %s, value: %s)", call.name, selfType, luaType),
		string.format("---@field Get%s fun(self: %s): %s", call.name, selfType, luaType)
	}

	local docText = table.concat(docs, "\n") .. "\n"

	return {
		start = insertPos - 1,
		finish = insertPos - 1,
		text = docText
	}
end

---Creates documentation diff for NetworkVarElement
---@param call table NetworkVarElement call info
---@param global string|nil Global scope
---@param class string|nil Class name
---@param config table Configuration
---@param text string Full file content
---@return table|nil diff Documentation diff
function NetworkVarProcessor.createNetworkVarElementDocumentation(call, global, class, config, text)
	-- Resolve the data type
	local luaType = NetworkVarProcessor.resolveDtType(call.type, config)

	-- Find insertion point
	local insertPos = call.position

	-- Generate documentation
	local selfType = class or global or "Entity"
	local docs = {
		string.format("---@field Set%s fun(self: %s, value: %s)", call.name, selfType, luaType),
		string.format("---@field Get%s fun(self: %s): %s", call.name, selfType, luaType)
	}

	local docText = table.concat(docs, "\n") .. "\n"

	return {
		start = insertPos - 1,
		finish = insertPos - 1,
		text = docText
	}
end

---Resolves DT type to Lua type
---@param dtType string Data table type
---@param config table Configuration
---@return string luaType
function NetworkVarProcessor.resolveDtType(dtType, config)
	local dtTypes = config.dtTypes or {}
	return dtTypes[dtType] or "any"
end

---Checks if text contains NetworkVar calls
---@param text string File content
---@param patterns table Pattern configurations
---@return boolean hasNetworkVars
function NetworkVarProcessor.hasNetworkVars(text, patterns)
	local networkVarPattern = patterns.networkVar or "NetworkVar%s*%("
	local networkVarElementPattern = patterns.networkVarElement or "NetworkVarElement%s*%("

	return text:find(networkVarPattern) ~= nil or text:find(networkVarElementPattern) ~= nil
end

return NetworkVarProcessor
