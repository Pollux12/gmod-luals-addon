--[[
	LuaLS plugin for Garry's Mod

	Includes code from https://github.com/TIMONz1535/glua-api-snippets/tree/plugin-wip1
	Includes code from https://github.com/CFC-Servers/luals_gmod_include

	This started as a project to combine both but ended up adding a bunch of new things and making a few fixes. It currently has:

	- Proper Include Paths resolution
	- Scripted Class Detection (ENT, SWEP, EFFECT, TOOL) with automated class annotation and inheritance detection
	- Derma Class automated annotation with inheritance detection
	- NetworkVar getter/setter annotation with proper type inference
	- AccessorFunc getter/setter annotation with force type support
	- Various fixes with class + hook inheritence (e.g PANEL and Panel caused issues)
	- plugin.config.lua to configure some stuff easily

	Potential issues:
	- Performance, as I've not benchmarked this at all. It seems okay, or at least not noticeable compared to how LuaLS is normally for me.
--]]

local guide = require "parser.guide"
local helper = require "plugins.astHelper"
local fs = require("bee.filesystem")

local Defaults = require("plugin.defaults")
local FolderDetection = require("plugin.folder-detection")
local DermaProcessor = require("plugin.derma-processor")
local AccessorProcessor = require("plugin.accessor-processor")
local NetworkVarProcessor = require("plugin.networkvar-processor")

--[[
	Cache Management Module

	Provides centralized cache management with size limits to prevent memory leaks.
	Supports multiple cache types with automatic cleanup when limits are exceeded.
--]]
local CacheManager = {}
local caches = {
	uriExists = {},
	folderBase = {},
	config = nil -- Special case for config caching
}

-- Cache size limits to prevent memory leaks
local CACHE_LIMITS = {
	uriExists = 1000,
	folderBase = 100
}

---Clears a specific cache or all caches
---@param cacheName? string
function CacheManager.clear(cacheName)
	if cacheName then
		if caches[cacheName] then
			if type(caches[cacheName]) == "table" then
				for k in pairs(caches[cacheName]) do
					caches[cacheName][k] = nil
				end
			else
				caches[cacheName] = nil
			end
		end
	else
		-- Clear all caches
		for name in pairs(caches) do
			CacheManager.clear(name)
		end
	end
end

---Manages cache size by removing oldest entries when limit is exceeded
---@param cacheName string
local function manageCacheSize(cacheName)
	local cache = caches[cacheName]
	local limit = CACHE_LIMITS[cacheName]
	if not cache or not limit then return end

	local count = 0
	for _ in pairs(cache) do
		count = count + 1
	end

	if count > limit then
		-- Simple strategy: clear half the cache
		local toRemove = math.floor(count / 2)
		local removed = 0
		for k in pairs(cache) do
			cache[k] = nil
			removed = removed + 1
			if removed >= toRemove then break end
		end
	end
end

---@param uri string
---@return boolean
local function uriExists(uri)
	local cache = caches.uriExists
	local cached = cache[uri]
	if cached ~= nil then
		return cached
	end

	local path = uri:sub(8)
	local exists = fs.exists(path)
	cache[uri] = exists

	manageCacheSize("uriExists")
	return exists
end

-- Error Handling Utilities Module
local ErrorHandler = {}

---Safely executes a function and logs errors
---@param func function
---@param context string
---@return any|nil result, string|nil error
function ErrorHandler.safeCall(func, context)
	local ok, result = pcall(func)
	if not ok then
		-- In a real plugin, you might want to log this to a file or debug console
		-- For now, we'll just return the error
		return nil, string.format("Error in %s: %s", context, tostring(result))
	end
	return result, nil
end

-- Use defaults from the Defaults module
local defaultScriptedScopes = Defaults.scopes

--[[
	Configuration Management Module

	Handles loading and merging of plugin configuration from plugin.config.lua.
	Provides type-safe configuration access with validation and default fallbacks.
--]]
local ConfigManager = {}



---@return table|nil
local function loadConfig()
	if caches.config ~= nil then
		return caches.config or nil
	end
	-- Use standard require for plugin config; simpler and follows KISS.
	local cfg = ErrorHandler.safeCall(function()
		return require("plugin.config")
	end, "loadConfig")

	if cfg and type(cfg) == "table" then
		caches.config = cfg
		return cfg
	end

	caches.config = false
	return nil
end

---Merges default configuration with user configuration
---@param defaultConfig table
---@param configKey string
---@param validator? function
---@return table
function ConfigManager.getMergedConfig(defaultConfig, configKey, validator)
	local cfg = loadConfig()
	local merged = {}

	-- Copy defaults
	for k, v in pairs(defaultConfig) do
		merged[k] = v
	end

	-- Merge user config if available
	if cfg and type(cfg[configKey]) == "table" then
		for k, v in pairs(cfg[configKey]) do
			if not validator or validator(k, v) then
				merged[k] = v
			end
		end
	end

	return merged
end

---@return table
function ConfigManager.getScopes()
	local cfg = loadConfig()
	if cfg and type(cfg.scopes) == "table" then
		return cfg.scopes
	end
	return defaultScriptedScopes
end

-- Use defaults from the Defaults module
local defaultDtTypes = Defaults.dtTypes
local defaultAccessorForceTypes = Defaults.accessorForceTypes

-- Validators for configuration merging
local function isValidStringPair(k, v)
	return type(k) == "string" and type(v) == "string" and v ~= ""
end

local function isValidBooleanPair(k, v)
	return type(k) == "string" and (v == true or v == false)
end

---@return table<string,string>
function ConfigManager.getDtTypes()
	return ConfigManager.getMergedConfig(defaultDtTypes, "dtTypes", isValidStringPair)
end

---@return table<string,string>
function ConfigManager.getAccessorForceTypes()
	return ConfigManager.getMergedConfig(defaultAccessorForceTypes, "accessorForceTypes", isValidStringPair)
end

-- Use defaults from the Defaults module
local defaultBaseGmodMap = Defaults.baseGmodMap

---@return table<string, boolean>
function ConfigManager.getBaseGmodMap()
	local merged = ConfigManager.getMergedConfig(defaultBaseGmodMap, "baseGmodMap", isValidBooleanPair)
	-- Convert keys to lowercase for case-insensitive matching
	local lowercased = {}
	for k, v in pairs(merged) do
		lowercased[k:lower()] = v
	end
	return lowercased
end

---Gets pattern configurations
---@return table
function ConfigManager.getPatterns()
	local cfg = loadConfig()
	if cfg and type(cfg.patterns) == "table" then
		return ConfigManager.getMergedConfig(Defaults.patterns, "patterns")
	end
	return Defaults.patterns
end

---Gets numeric mappings for AccessorFunc force types
---@return table
function ConfigManager.getAccessorForceTypesByNumber()
	return Defaults.accessorForceTypesByNumber
end

---@return table
function ConfigManager.getConfig()
	return {
		patterns = ConfigManager.getPatterns(),
		scopes = ConfigManager.getScopes(),
		dtTypes = ConfigManager.getDtTypes(),
		accessorForceTypes = ConfigManager.getAccessorForceTypes(),
		baseGmodMap = ConfigManager.getBaseGmodMap(),
		accessorForceTypesByNumber = ConfigManager.getAccessorForceTypesByNumber()
	}
end

--[[
	Pattern Matching Utilities Module

	Provides reusable pattern matching functions for parsing Garry's Mod Lua code.
	Handles vgui.Register, derma.DefineControl, AccessorFunc calls, and variable assignments.
--]]
local PatternUtils = {}

-- Common patterns used throughout the plugin
local PATTERNS = {
	VGUI_REGISTER_WITH_BASE =
	"vgui%s*%.%s*Register%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*([%a_][%w_]*)%s*,%s*['\"]([^'\"]+)['\"]%s*%)",
	VGUI_REGISTER_NO_BASE = "vgui%s*%.%s*Register%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*([%a_][%w_]*)%s*%)",
	DERMA_DEFINE_WITH_BASE =
	"derma%s*%.%s*DefineControl%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*['\"][^'\"]*['\"]%s*,%s*([%a_][%w_]*)%s*,%s*['\"]([^'\"]+)['\"]%s*%)",
	DERMA_DEFINE_NO_BASE =
	"derma%s*%.%s*DefineControl%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*['\"][^'\"]*['\"]%s*,%s*([%a_][%w_]*)%s*%)",
	ACCESSOR_FUNC_WITH_FORCE =
	"AccessorFunc%s*%(%s*([%a_][%w_]*)%s*,%s*['\"]([^'\"]+)['\"]%s*,%s*['\"]([^'\"]+)['\"]%s*,%s*([%a_][%w_]*)%s*%)",
	ACCESSOR_FUNC_NO_FORCE = "AccessorFunc%s*%(%s*([%a_][%w_]*)%s*,%s*['\"]([^'\"]+)['\"]%s*,%s*['\"]([^'\"]+)['\"]%s*%)",
	LOCAL_VAR_ASSIGNMENT = "()local%s+([%a_][%w_]*)%s*=%s*%b{}()",
	GLOBAL_VAR_ASSIGNMENT = "([%a_][%w_]*)%s*=%s*%b{}",
	BASE_ASSIGNMENT_IDENT = "%.%s*Base%s*=%s*([%a_][%w_%.]*)",
	BASE_ASSIGNMENT_STRING = "%.%s*Base%s*=%s*[\"']([^\"']+)[\"']"
}

---Finds all matches of a pattern in text and returns structured results
---@param text string
---@param pattern string
---@param captureNames string[]
---@return table[]
function PatternUtils.findAllMatches(text, pattern, captureNames)
	local matches = {}
	local pos = 1

	while true do
		local captures = { string.find(text, pattern, pos) }
		if not captures[1] then break end

		local match = {
			start = captures[1],
			finish = captures[2]
		}

		-- Add named captures
		for i, name in ipairs(captureNames) do
			match[name] = captures[i + 2]
		end

		matches[#matches + 1] = match
		pos = captures[2] + 1
	end

	return matches
end

---Finds vgui.Register calls in text
---@param text string
---@return table[]
function PatternUtils.findVguiRegisters(text)
	local registers = {}

	-- Find registers with base class
	local withBase = PatternUtils.findAllMatches(text, PATTERNS.VGUI_REGISTER_WITH_BASE,
		{ "className", "varName", "baseName" })
	for _, match in ipairs(withBase) do
		match.type = "vgui.Register"
		match.class = match.className
		match.var = match.varName
		match.base = match.baseName
		registers[#registers + 1] = match
	end

	-- Find registers without base class
	local withoutBase = PatternUtils.findAllMatches(text, PATTERNS.VGUI_REGISTER_NO_BASE,
		{ "className", "varName" })
	for _, match in ipairs(withoutBase) do
		match.type = "vgui.Register"
		match.class = match.className
		match.var = match.varName
		match.base = nil
		registers[#registers + 1] = match
	end

	return registers
end

---Finds derma.DefineControl calls in text
---@param text string
---@return table[]
function PatternUtils.findDermaDefines(text)
	local defines = {}

	-- Find defines with base class
	local withBase = PatternUtils.findAllMatches(text, PATTERNS.DERMA_DEFINE_WITH_BASE,
		{ "className", "varName", "baseName" })
	for _, match in ipairs(withBase) do
		match.type = "derma.DefineControl"
		match.class = match.className
		match.var = match.varName
		match.base = match.baseName
		defines[#defines + 1] = match
	end

	-- Find defines without base class
	local withoutBase = PatternUtils.findAllMatches(text, PATTERNS.DERMA_DEFINE_NO_BASE,
		{ "className", "varName" })
	for _, match in ipairs(withoutBase) do
		match.type = "derma.DefineControl"
		match.class = match.className
		match.var = match.varName
		match.base = nil
		defines[#defines + 1] = match
	end

	return defines
end

---Finds AccessorFunc calls in text
---@param text string
---@param global string|nil
---@param class string|nil
---@return table[]
function PatternUtils.findAccessorFuncs(text, global, class)
	local accessorFuncs = {}

	-- Find AccessorFunc calls with force type
	local withForce = PatternUtils.findAllMatches(text, PATTERNS.ACCESSOR_FUNC_WITH_FORCE,
		{ "tableVar", "varName", "funcName", "forceType" })
	for _, match in ipairs(withForce) do
		match.targetClass = (match.tableVar == global) and class or nil
		accessorFuncs[#accessorFuncs + 1] = match
	end

	-- Find AccessorFunc calls without force type
	local withoutForce = PatternUtils.findAllMatches(text, PATTERNS.ACCESSOR_FUNC_NO_FORCE,
		{ "tableVar", "varName", "funcName" })
	for _, match in ipairs(withoutForce) do
		match.forceType = nil
		match.targetClass = (match.tableVar == global) and class or nil
		accessorFuncs[#accessorFuncs + 1] = match
	end

	return accessorFuncs
end

---Finds variable table assignments in text
---@param text string
---@return table<string, table[]>
function PatternUtils.findVarTableAssignments(text)
	local assignsByVar = {}

	-- Find local variable assignments
	local localAssigns = PatternUtils.findAllMatches(text, PATTERNS.LOCAL_VAR_ASSIGNMENT, { "varName" })
	for _, match in ipairs(localAssigns) do
		local list = assignsByVar[match.varName] or {}
		list[#list + 1] = { s = match.start, e = match.finish - 1 }
		assignsByVar[match.varName] = list
	end

	-- Find global variable assignments (more complex logic needed)
	local pos = 1
	while true do
		local s, e, varName = string.find(text, PATTERNS.GLOBAL_VAR_ASSIGNMENT, pos)
		if not s then break end

		-- Check if this assignment is NOT preceded by "local" keyword
		local lineStart = text:sub(1, s):match(".*\n()[^\n]*$") or 1
		local beforeAssign = text:sub(lineStart, s - 1)
		if not beforeAssign:match("local%s+$") then
			local list = assignsByVar[varName] or {}
			list[#list + 1] = { s = s, e = e }
			assignsByVar[varName] = list
		end
		pos = e + 1
	end

	return assignsByVar
end

local function findFolderBase(uri, global, class)
	-- Use the new FolderDetection module with configuration
	local config = ConfigManager.getConfig()
	return FolderDetection.detectFolderStructure(uri, global, class, config)
end

-- Text Processing Utilities Module
local TextProcessor = {}

---Checks if a class documentation already exists in text
---@param text string
---@param className string
---@return boolean
function TextProcessor.hasExistingClassDoc(text, className)
	local pattern = "---@class%s+" .. className .. "[%s: ]"
	return string.find(text, pattern) ~= nil
end

---Checks if a class documentation exists before a specific position
---@param text string
---@param className string
---@param beforePos integer
---@return boolean
function TextProcessor.hasClassDocBefore(text, className, beforePos)
	-- Check within a small window above the insertion point for an existing class doc
	local start = math.max(1, (beforePos or 1) - 800)
	local slice = text:sub(start, math.max(start, (beforePos or 1) - 1))
	local pattern = "---@class%s+" .. className .. "[%s: ]"
	return slice:find(pattern) ~= nil
end

---Finds the nearest assignment before a given position
---@param assigns table[]|nil
---@param beforePos integer
---@return table|nil
function TextProcessor.findNearestPriorAssignment(assigns, beforePos)
	if not assigns then return nil end
	local best
	for _, a in ipairs(assigns) do
		if a.s < beforePos then
			if not best or a.s > best.s then
				best = a
			end
		end
	end
	return best
end

---Generates field documentation for accessor functions
---@param accessorFuncs table[]
---@param varName string
---@param className string
---@param startPos integer
---@param endPos integer
---@return string[]
function TextProcessor.generateAccessorFieldDocs(accessorFuncs, varName, className, startPos, endPos)
	local fieldDocs = {}
	local accessorForceTypes = ConfigManager.getAccessorForceTypes()

	for _, accessor in ipairs(accessorFuncs) do
		if accessor.tableVar == varName and accessor.start > startPos and accessor.start < endPos then
			local forceType = "any"
			if accessor.forceType then
				forceType = accessorForceTypes[accessor.forceType] or "any"
			end

			fieldDocs[#fieldDocs + 1] = ("---@field Get%s fun(self: %s): %s"):format(accessor.funcName, className,
				forceType)
			fieldDocs[#fieldDocs + 1] = ("---@field Set%s fun(self: %s, value: %s)"):format(accessor.funcName, className,
				forceType)

			if accessor.varName then
				fieldDocs[#fieldDocs + 1] = ("---@field protected %s %s"):format(accessor.varName, forceType)
			end
		end
	end

	return fieldDocs
end

-- Class Detection Utilities Module
local ClassDetection = {}

---Normalises a URI path and splits it into segments
---@param uri string
---@return string[] segments
function ClassDetection.parseUriPath(uri)
	local uriPath = uri:gsub("\\", "/")
	local normUri = uriPath:lower()

	local segments = {}
	for seg in normUri:gmatch("[^/]+") do
		segments[#segments + 1] = seg
	end

	return segments
end

---Converts scope configurations into searchable format
---@return table[] scopes
function ClassDetection.prepareScopes()
	local scopes = {}
	for _, sc in ipairs(ConfigManager.getScopes()) do
		local folder = (sc.folder or ""):gsub("\\", "/"):gsub("/+", "/"):lower()
		local folderSegs = {}
		for s in folder:gmatch("[^/]+") do
			folderSegs[#folderSegs + 1] = s
		end
		if #folderSegs > 0 then
			scopes[#scopes + 1] = { global = sc.global, segs = folderSegs }
		end
	end
	return scopes
end

---Finds the best matching scope for the given path segments
---@param segments string[]
---@param scopes table[]
---@return table|nil best
function ClassDetection.findBestScope(segments, scopes)
	local best = nil -- {global=string, endIndex=integer, len=integer}

	for _, sc in ipairs(scopes) do
		local fsegs = sc.segs
		local flen = #fsegs
		-- start from (#segments - flen + 1) to include last valid position
		for i = #segments - flen + 1, 1, -1 do
			local match = true
			for j = 1, flen do
				if segments[i + j - 1] ~= fsegs[j] then
					match = false
					break
				end
			end
			if match then
				local endIndex = i + flen - 1
				if not best or endIndex > best.endIndex or (endIndex == best.endIndex and flen > best.len) then
					best = { global = sc.global, endIndex = endIndex, len = flen }
				end
				break -- Stop after first (nearest) match
			end
		end
	end

	return best
end

---Determines the class name from path segments and scope match
---@param segments string[]
---@param best table
---@return string|nil class
function ClassDetection.determineClassName(segments, best)
	local afterIdx = best.endIndex + 1
	if afterIdx > #segments then return nil end

	local lastSeg = segments[#segments]
	local class
	if afterIdx == #segments then
		-- Single file directly under scope folder: <class>.lua
		class = lastSeg:gsub("%.lua$", "")
	else
		-- Any other nested file belongs to the first directory after the scope
		class = segments[afterIdx]
	end

	return (class and class ~= "") and class or nil
end

---@param uri string
---@return string? global, string? class
local function GetScopedClass(uri)
	local segments = ClassDetection.parseUriPath(uri)
	if #segments == 0 then return end

	local scopes = ClassDetection.prepareScopes()
	if #scopes == 0 then return end

	local best = ClassDetection.findBestScope(segments, scopes)
	if not best then return end

	local class = ClassDetection.determineClassName(segments, best)
	if class then
		return best.global, class
	end
end

---@class PluginDiff
---@field start integer # The number of bytes at the beginning of the replacement
---@field finish integer # The number of bytes at the end of the replacement
---@field text string   # Replacement text

---Processes scripted class detection and generates documentation
---@param uri string File URI
---@param text string File content
---@param global string Global scope
---@param class string Class name
---@return PluginDiff[] diffs Array of documentation diffs
local function processScriptedClassDiffs(uri, text, global, class)
	local diffs = {}
	local config = ConfigManager.getConfig()
	local patterns = config.patterns

	-- Check if this file has Derma panel registrations to avoid conflicts
	local hasDermaRegistrations = DermaProcessor.hasDermaRegistrations(text, patterns)

	local localPattern = "%f[%a]local%s+" .. global .. "%s*="
	local hasLocal = string.find(text, localPattern) ~= nil

	local folderBase = findFolderBase(uri, global, class)
	local baseIdent, baseString
	if folderBase then
		if folderBase.kind == "ident" then
			baseIdent = folderBase.value
		else
			baseString = folderBase.value
		end
	else
		baseIdent = text:match(global .. "%.%s*Base%s*=%s*([%a_][%w_%.]*)")
		baseString = text:match(global .. "%.%s*Base%s*=%s*[\"']([^\"']+)[\"']")
	end

	local parent = global
	local localText = ""
	if baseIdent then
		parent = baseIdent
		if not hasLocal then
			localText = ("local %s = %s\n\n"):format(global, baseIdent)
		end
	elseif baseString then
		local baseMap = ConfigManager.getBaseGmodMap()
		if baseMap[baseString:lower()] then
			parent = global
		else
			parent = baseString
		end
		if not hasLocal then
			localText = ("local %s = {}\n\n"):format(global)
		end
	else
		if not hasLocal then
			localText = ("local %s = {}\n\n"):format(global)
		end
	end

	if class and not hasDermaRegistrations then
		local alreadyHasClassDoc = TextProcessor.hasExistingClassDoc(text, class)

		-- Process AccessorFunc calls for this scripted class
		local accessorDiffs = AccessorProcessor.processAccessorFuncs(text, global, class, config)
		local fieldDocs = {}

		-- Extract field documentation from accessor diffs
		for _, diff in ipairs(accessorDiffs) do
			if diff.text then
				for line in diff.text:gmatch("[^\n]+") do
					if line:match("^%-%-%-@field") then
						fieldDocs[#fieldDocs + 1] = line
					end
				end
			end
		end

		if not alreadyHasClassDoc then
			local classDoc = ("---@class %s : %s"):format(class, parent)
			if #fieldDocs > 0 then
				classDoc = classDoc .. "\n" .. table.concat(fieldDocs, "\n")
			end
			diffs[#diffs + 1] = {
				start = 1,
				finish = 0,
				text = classDoc .. "\n" .. localText,
			}
		elseif localText ~= "" then
			-- Class doc exists; only ensure local stub is present
			diffs[#diffs + 1] = {
				start = 1,
				finish = 0,
				text = localText,
			}
		end
	else
		if localText ~= "" then
			diffs[#diffs + 1] = {
				start = 1,
				finish = 0,
				text = localText,
			}
		end
	end

	return diffs
end

---Processes DEFINE_BASECLASS replacements
---@param text string File content
---@return PluginDiff[] diffs Array of documentation diffs
local function processDefineBaseclass(text)
	local diffs = {}
	local idx = 1
	while true do
		local s, e = string.find(text, "DEFINE_BASECLASS", idx, true)
		if not s then break end
		diffs[#diffs + 1] = {
			start = s,
			finish = e,
			text = "local BaseClass = baseclass.Get",
		}
		idx = e + 1
	end
	return diffs
end

---@param uri string # File URI
---@param text string # File content
---@return PluginDiff[]|nil
function OnSetText(uri, text)
	local result = ErrorHandler.safeCall(function()
		---@type PluginDiff[]
		local diffs = {}
		local config = ConfigManager.getConfig()

		-- Handle scripted class (ENT/SWEP/EFFECT/TOOL) detection and localization
		local global, class = GetScopedClass(uri)
		if global then
			local scriptedDiffs = processScriptedClassDiffs(uri, text, global, class)
			for _, diff in ipairs(scriptedDiffs) do
				diffs[#diffs + 1] = diff
			end
		end

		-- Handle DEFINE_BASECLASS replacement
		local baseclassDiffs = processDefineBaseclass(text)
		for _, diff in ipairs(baseclassDiffs) do
			diffs[#diffs + 1] = diff
		end

		-- Handle Derma panels (vgui.Register and derma.DefineControl)
		local dermaDiffs = DermaProcessor.processDermaRegistrations(text, config)
		for _, diff in ipairs(dermaDiffs) do
			diffs[#diffs + 1] = diff
		end

		-- Handle NetworkVar calls
		local networkVarDiffs = NetworkVarProcessor.processNetworkVars(text, global, class, config)
		for _, diff in ipairs(networkVarDiffs) do
			diffs[#diffs + 1] = diff
		end

		if #diffs == 0 then
			return nil
		end
		return diffs
	end, "OnSetText")

	-- Return result or nil on error
	return result
end

---@param ast any
---@param classNode any
---@param name string
---@param selfType string
---@param valueType string
---@param group table
---@return boolean|nil
local function addGetSetDocs(ast, classNode, name, selfType, valueType, group)
	local ok = helper.addDoc(ast, classNode, "field",
		("Set%s fun(self: %s, value: %s)"):format(name, selfType, valueType), group)
	if not ok then
		return false
	end
	ok = helper.addDoc(ast, classNode, "field", ("Get%s fun(self: %s): %s"):format(name, selfType, valueType), group)
	if not ok then
		return false
	end
end

---@param ast any
---@param classNode any
---@param source any
---@param group table
---@param isElement boolean
---@return boolean|nil
local function BindNetworkVar(ast, classNode, source, group, isElement)
	local args = guide.getParams(source)
	if not args or #args < (isElement and 4 or 3) then
		return
	end

	local argSelf = args[1]
	local targetSelf = guide.getSelfNode(argSelf)
	if not targetSelf then
		return
	end
	if targetSelf.node ~= classNode then
		targetSelf = guide.getSelfNode(targetSelf)
		if not targetSelf or targetSelf.node ~= classNode then
			return
		end
	end

	local argType = args[2]
	local argSlot = args[3]
	local argName = args[isElement and 5 or 4]

	if isElement then
		local argElement = args[4]
		if argSlot.type == "string" and argElement.type == "string" then
			argName = argElement
		end
	else
		if argSlot.type == "string" and (not argName or argName.type == "table") then
			argName = argSlot
		end
	end
	if not (argType and argType.type == "string" and argName and argName.type == "string") then
		return
	end

	local dtMap = ConfigManager.getDtTypes()
	local dtType = isElement and "number" or dtMap[argType[1]]
	local name = argName[1]
	if not dtType then
		return
	end

	return addGetSetDocs(ast, classNode, name, "Entity", dtType, group)
end




---@param tbl any
---@param wanted string
---@return any|nil
local function findClassNode(tbl, wanted)
	if type(tbl) ~= "table" then return nil end
	for i = 1, #tbl do
		local n = tbl[i]
		if n and n.type == "local" and guide.getKeyName(n) == wanted then
			return n
		end
	end
	for _, n in pairs(tbl) do
		if n and type(n) == "table" and n.type == "local" and guide.getKeyName(n) == wanted then
			return n
		end
	end
	return nil
end

---@param node any
---@return boolean
local function isInsideSetupDataTables(node)
	local p = node
	for _ = 1, 12 do
		if not p or not p.parent then
			break
		end
		p = p.parent
		if guide.getKeyName(p) == "SetupDataTables" then
			return true
		end
	end
	return false
end



---@param uri string
---@param ast any
---@param group table
---@return any|nil classNode, string|nil global, string|nil class
local function processScriptedClass(uri, ast, group)
	local global, class = GetScopedClass(uri)
	if not global then
		return nil, nil, nil
	end
	local classNode = findClassNode(ast, global)
	if not classNode then
		return nil, nil, nil
	end
	local ok = helper.addClassDoc and helper.addClassDoc(ast, classNode, class .. ": " .. global, group)
	if ok == false then
		return nil, nil, nil
	end
	-- Bind NetworkVar/NetworkVarElement calls inside SetupDataTables on this class
	ok = guide.eachSourceType(ast, "call", function(source)
		local targetMethod = source.node
		local targetName = guide.getKeyName(targetMethod)
		if targetName ~= "NetworkVar" and targetName ~= "NetworkVarElement" then
			return
		end
		if not isInsideSetupDataTables(source) then
			return
		end
		local targetSelf = targetMethod.node and guide.getSelfNode(targetMethod.node)
		if not targetSelf or targetSelf.node ~= classNode then
			return
		end
		return BindNetworkVar(ast, classNode, source, group, targetName == "NetworkVarElement")
	end)
	if ok == false then
		-- Do not abort other passes if NetworkVar binding fails
		return classNode, global, class
	end
	return classNode, global, class
end





---@param uri string # File URI
---@param ast any # File AST
---@return any|nil
function OnTransformAst(uri, ast)
	local group = {}
	processScriptedClass(uri, ast, group)
	-- Moved vgui panels and AccessorFunc processing to OnSetText, since it's easier to debug using the diff view.
	return ast
end

---@param uri string # The workspace or top-level URI
---@param name string # Argument of require()
---@return string[]|nil
function ResolveRequire(uri, name)
	if string.sub(name, -4) ~= ".lua" then
		return nil
	end

	-- See https://github.com/LuaLS/LuaLS.github.io/issues/48
	local _callingName, callingURI = debug.getlocal(5, 2)
	do
		assert(_callingName == "suri", "Something broke! Did LuaLS update?")
	end

	local callingDirURI = callingURI:match("^(.*)/[^/]*$")

	local relative = callingDirURI .. "/" .. name
	if uriExists(relative) then
		return { relative }
	end

	local absolute = uri .. "/lua/" .. name
	return { absolute }
end
