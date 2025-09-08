--[[
	Handles all Derma/VGUI panel registration processing.
--]]

local DermaProcessor = {}

---Processes Derma panel registrations in text and generates documentation diffs
---@param text string File content
---@param config table Configuration with patterns
---@return table[] diffs Array of documentation diffs
function DermaProcessor.processDermaRegistrations(text, config)
	local diffs = {}
	local patterns = config.patterns or {}

	-- Process vgui.Register calls
	local vguiDiffs = DermaProcessor.processVguiRegistrations(text, patterns)
	for _, diff in ipairs(vguiDiffs) do
		diffs[#diffs + 1] = diff
	end

	-- Process derma.DefineControl calls
	local dermaDiffs = DermaProcessor.processDermaDefineControl(text, patterns)
	for _, diff in ipairs(dermaDiffs) do
		diffs[#diffs + 1] = diff
	end

	return diffs
end

---Processes vgui.Register calls in text
---@param text string File content
---@param patterns table Pattern configurations
---@return table[] diffs Array of documentation diffs
function DermaProcessor.processVguiRegistrations(text, patterns)
	local diffs = {}
	local vguiPattern = patterns.vguiRegister or "vgui%s*%.%s*Register%s*%("

	-- Find all vgui.Register calls
	local registrations = DermaProcessor.findVguiRegistrations(text, vguiPattern)

	for _, registration in ipairs(registrations) do
		local diff = DermaProcessor.createVguiDocumentation(registration, text)
		if diff then
			diffs[#diffs + 1] = diff
		end
	end

	return diffs
end

---Processes derma.DefineControl calls in text
---@param text string File content
---@param patterns table Pattern configurations
---@return table[] diffs Array of documentation diffs
function DermaProcessor.processDermaDefineControl(text, patterns)
	local diffs = {}
	local dermaPattern = patterns.dermaDefineControl or "derma%s*%.%s*DefineControl%s*%("

	-- Find all derma.DefineControl calls
	local definitions = DermaProcessor.findDermaDefinitions(text, dermaPattern)

	for _, definition in ipairs(definitions) do
		local diff = DermaProcessor.createDermaDocumentation(definition, text)
		if diff then
			diffs[#diffs + 1] = diff
		end
	end

	return diffs
end

---Finds vgui.Register calls in text
---@param text string File content
---@param pattern string Search pattern
---@return table[] registrations Array of registration info
function DermaProcessor.findVguiRegistrations(text, pattern)
	local registrations = {}

	for match in text:gmatch(pattern .. "([^%)]*%)") do
		local args = DermaProcessor.parseVguiArgs(match)
		if args and args.name and args.table then
			registrations[#registrations + 1] = {
				name = args.name,
				table = args.table,
				base = args.base,
				position = text:find(pattern .. match, 1, true) or 0
			}
		end
	end

	return registrations
end

---Finds derma.DefineControl calls in text
---@param text string File content
---@param pattern string Search pattern
---@return table[] definitions Array of definition info
function DermaProcessor.findDermaDefinitions(text, pattern)
	local definitions = {}

	for match in text:gmatch(pattern .. "([^%)]*%)") do
		local args = DermaProcessor.parseDermaArgs(match)
		if args and args.name and args.table then
			definitions[#definitions + 1] = {
				name = args.name,
				description = args.description,
				table = args.table,
				base = args.base,
				position = text:find(pattern .. match, 1, true) or 0
			}
		end
	end

	return definitions
end

---Parses vgui.Register arguments
---@param argsText string Arguments text
---@return table|nil args Parsed arguments
function DermaProcessor.parseVguiArgs(argsText)
	-- Simple argument parsing - in a real implementation this would be more robust
	local name = argsText:match([["([^"]+)"]]) or argsText:match([['([^']+)']])
	if not name then return nil end

	-- Extract table reference (simplified)
	local tableRef = argsText:match(",%s*([%a_][%w_%.]*)")
	if not tableRef then return nil end

	-- Extract base class if present
	local base = argsText:match([[,%s*"([^"]+)"]]) or argsText:match([[,%s*'([^']+)']])

	return {
		name = name,
		table = tableRef,
		base = base
	}
end

---Parses derma.DefineControl arguments
---@param argsText string Arguments text
---@return table|nil args Parsed arguments
function DermaProcessor.parseDermaArgs(argsText)
	-- Simple argument parsing for derma.DefineControl
	local name = argsText:match([["([^"]+)"]]) or argsText:match([['([^']+)']])
	if not name then return nil end

	-- Extract description (second string argument)
	local remaining = argsText:match([[^[^,]*,%s*"[^"]*",%s*(.*)$]]) or
		argsText:match([[^[^,]*,%s*'[^']*',%s*(.*)$]])
	if not remaining then return nil end

	-- Extract table reference
	local tableRef = remaining:match("([%a_][%w_%.]*)")
	if not tableRef then return nil end

	-- Extract base class if present
	local base = remaining:match([[,%s*"([^"]+)"]]) or remaining:match([[,%s*'([^']+)']])

	return {
		name = name,
		table = tableRef,
		base = base
	}
end

---Creates documentation diff for vgui registration
---@param registration table Registration info
---@param text string Full file content
---@return table|nil diff Documentation diff
function DermaProcessor.createVguiDocumentation(registration, text)
	-- Find the table definition location
	local tablePattern = "local%s+" .. registration.table:gsub("%.", "%%%.") .. "%s*="
	local tablePos = text:find(tablePattern)

	if not tablePos then
		return nil
	end

	-- Generate class documentation
	local className = registration.name
	local baseClass = registration.base or "Panel"

	local docText = string.format("---@class %s : %s\n", className, baseClass)

	return {
		start = tablePos - 1,
		finish = tablePos - 1,
		text = docText
	}
end

---Creates documentation diff for derma definition
---@param definition table Definition info
---@param text string Full file content
---@return table|nil diff Documentation diff
function DermaProcessor.createDermaDocumentation(definition, text)
	-- Find the table definition location
	local tablePattern = "local%s+" .. definition.table:gsub("%.", "%%%.") .. "%s*="
	local tablePos = text:find(tablePattern)

	if not tablePos then
		return nil
	end

	-- Generate class documentation
	local className = definition.name
	local baseClass = definition.base or "Panel"

	local docText = string.format("---@class %s : %s\n", className, baseClass)

	return {
		start = tablePos - 1,
		finish = tablePos - 1,
		text = docText
	}
end

---Checks if text contains Derma registrations
---@param text string File content
---@param patterns table Pattern configurations
---@return boolean hasRegistrations
function DermaProcessor.hasDermaRegistrations(text, patterns)
	local vguiPattern = patterns.vguiRegister or "vgui%s*%.%s*Register%s*%("
	local dermaPattern = patterns.dermaDefineControl or "derma%s*%.%s*DefineControl%s*%("

	return text:find(vguiPattern) ~= nil or text:find(dermaPattern) ~= nil
end

return DermaProcessor
