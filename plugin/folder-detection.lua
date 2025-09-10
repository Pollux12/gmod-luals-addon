--[[
	Handles the detection of whether a class is defined in a single file or across multiple files in a folder.
--]]

local FolderDetection = {}

-- Import filesystem module
local fs = require("bee.filesystem")

-- Cache for folder base results to improve performance
local folderBaseCache = {}

---Converts URI to filesystem path
---@param uri string
---@return string
local function uriToPath(uri)
	if uri:match("^file://") then
		local path = uri:sub(8) -- Remove "file://" prefix
		-- Handle Windows paths
		if path:match("^/[A-Za-z]:") then
			path = path:sub(2) -- Remove leading slash for Windows paths like /C:/
		end
		return path
	end
	return uri
end

---Reads file content using bee.filesystem
---@param filePath string
---@return string|nil
local function readFile(filePath)
	local fsPath = uriToPath(filePath)
	if not fs.exists(fsPath) then
		return nil
	end

	-- Use io.open for reading since bee.filesystem doesn't have a read method
	local file = io.open(fsPath, "r")
	if not file then
		return nil
	end
	local content = file:read("*all")
	file:close()
	return content
end

---Checks if any files in a directory match the given patterns
---@param dir string
---@param patterns string[]
---@return boolean
local function hasMatchingFiles(dir, patterns)
	local fsPath = uriToPath(dir)

	-- Check if any of the pattern files exist using bee.filesystem
	for _, pattern in ipairs(patterns) do
		-- For simple filenames, check directly
		if not pattern:match("[%*%?%[%]]") then
			local filePath = fsPath .. "/" .. pattern
			if fs.exists(filePath) then
				return true
			end
		end
	end

	return false
end

---Determines if a class should be applied to an entire folder based on detection patterns
---@param uri string File URI
---@param global string Global scope (ENT, SWEP, etc.)
---@param class string Class name
---@param config table Configuration with scopes containing folderIndicators and additionalPatterns
---@return table|nil folderInfo Information about folder detection
function FolderDetection.detectFolderStructure(uri, global, class, config)
	local callingDir = uri:match("^(.*)/[^/]*$")
	if not callingDir then
		return nil
	end

	local fileName = uri:match("[^/]+$") or ""
	fileName = fileName:lower()

	-- Get detection patterns for this scope type from scopes configuration
	local detectionConfig = nil
	if config.scopes then
		for _, scope in ipairs(config.scopes) do
			if scope.global == global then
				detectionConfig = scope
				break
			end
		end
	end

	if not detectionConfig or not detectionConfig.folderIndicators then
		-- Fallback to basic detection if no config available
		return FolderDetection.basicFolderDetection(uri, global, class)
	end

	local folderIndicators = detectionConfig.folderIndicators or {}
	local additionalPatterns = detectionConfig.additionalPatterns or {}

	-- Check if current file is a folder indicator
	local isCurrentFileFolderIndicator = false
	for _, indicator in ipairs(folderIndicators) do
		if fileName == indicator then
			isCurrentFileFolderIndicator = true
			break
		end
	end

	local folderPath

	if isCurrentFileFolderIndicator then
		-- File is a folder indicator (like init.lua), apply to entire directory
		folderPath = callingDir
	else
		-- Check if we're in a class-named directory
		local parentName = callingDir:match("([^/]+)$")
		if parentName and parentName == class then
			-- We're in a directory named after the class
			-- Check if there are other files that suggest this is a folder-based structure
			if hasMatchingFiles(callingDir, folderIndicators) or
				hasMatchingFiles(callingDir, additionalPatterns) then
				folderPath = callingDir
			end
		end
	end

	if not folderPath then
		return nil
	end

	-- Determine base class information
	local baseInfo = FolderDetection.extractBaseFromFolder(folderPath, global, config)

	return {
		path = folderPath,
		kind = baseInfo and baseInfo.kind or "string",
		value = baseInfo and baseInfo.value or global
	}
end

---Basic folder detection fallback for when no configuration is available
---@param uri string
---@param global string
---@param class string
---@return table|nil
function FolderDetection.basicFolderDetection(uri, global, class)
	local callingDir = uri:match("^(.*)/[^/]*$")
	if not callingDir then
		return nil
	end

	local fileName = uri:match("[^/]+$") or ""
	fileName = fileName:lower()

	-- Basic folder indicators
	local commonHub = {
		["shared.lua"] = true,
		["init.lua"] = true,
		["cl_init.lua"] = true,
	}

	local folderPath
	if commonHub[fileName] then
		folderPath = callingDir
	else
		local parentName = callingDir:match("([^/]+)$")
		if parentName and parentName == class then
			folderPath = callingDir
		end
	end

	if not folderPath then
		return nil
	end

	return {
		path = folderPath,
		kind = "string",
		value = global
	}
end

---Extracts base class information from folder structure
---@param folderPath string
---@param global string
---@param config table
---@return table|nil baseInfo
function FolderDetection.extractBaseFromFolder(folderPath, global, config)
	-- Check cache first for performance
	local cacheKey = folderPath .. ":" .. global
	if folderBaseCache[cacheKey] then
		return folderBaseCache[cacheKey]
	end

	-- Get scope configuration for this global type
	local scopeConfig = nil
	if config and config.scopes then
		for _, scope in ipairs(config.scopes) do
			if scope.global == global then
				scopeConfig = scope
				break
			end
		end
	end

	if not scopeConfig or not scopeConfig.folderIndicators then
		-- No config available, return default
		local result = { kind = "string", value = global }
		folderBaseCache[cacheKey] = result
		return result
	end

	-- Search through configured folder indicator files
	for _, filename in ipairs(scopeConfig.folderIndicators) do
		local filePath = folderPath .. "/" .. filename
		local content = readFile(filePath)
		if content then
			-- Use the same pattern as single-file entities: global.Base = "some_base"
			local baseString = content:match(global .. "%.Base%s*=%s[\"\']([%w_]*)[\"\']")
			if baseString and baseString ~= "" then
				local result = { kind = "string", value = baseString }
				folderBaseCache[cacheKey] = result
				return result
			end
		end
	end

	-- No base class found, return default
	local result = { kind = "string", value = global }
	folderBaseCache[cacheKey] = result
	return result
end

---Checks if a directory contains files that match folder-based patterns
---@param dir string Directory path
---@param global string Global scope type
---@param config table Configuration
---@return boolean
function FolderDetection.isFolderBasedStructure(dir, global, config)
	-- Get detection patterns for this scope type from scopes configuration
	local detectionConfig = nil
	if config.scopes then
		for _, scope in ipairs(config.scopes) do
			if scope.global == global then
				detectionConfig = scope
				break
			end
		end
	end

	if not detectionConfig or not detectionConfig.folderIndicators then
		return false
	end

	local folderIndicators = detectionConfig.folderIndicators or {}
	local additionalPatterns = detectionConfig.additionalPatterns or {}

	-- Check for folder indicators
	if hasMatchingFiles(dir, folderIndicators) then
		return true
	end

	-- Check for additional patterns
	if hasMatchingFiles(dir, additionalPatterns) then
		return true
	end

	return false
end

return FolderDetection
