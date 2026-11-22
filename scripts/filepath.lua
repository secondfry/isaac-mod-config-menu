-- The FilepathHelper surface: Version on this table keeps Encyclopedia's own copy dormant, so every later mod gets a string `path` here.
return function(api)
	api.KnownFilePathsByName = {}
	api.KnownFilePathsByIndex = {}

	-- shortcut: require("") lists its search patterns as "no file '<pattern>.lua'" and the second is taken as the loading mod's root (FilepathHelper's rule, "" when absent), probe KnownFilePathsByIndex in game
	local function loadingModPath()
		local _, message = pcall(require, "")
		local found = 0
		for pattern in tostring(message):gmatch("no file '(.-)%.lua'") do
			found = found + 1
			if found == 2 then return (pattern:gsub("\\", "/")) end
		end
		return ""
	end

	function api.GetCurrentModPath()
		local path = loadingModPath()
		if path ~= "" and not api.KnownFilePathsByName[path] then
			api.KnownFilePathsByName[path] = true
			api.KnownFilePathsByIndex[#api.KnownFilePathsByIndex + 1] = path
		end
		return path
	end

	function api.DoFile(path) return include(path) end
	local function no() return false end
	api.TestPath, api.IsFile, api.IsDirectory, api.IsAnm2 = no, no, no, no

	api.OldRegisterMod = Isaac.RegisterMod
	function api.RegisterMod(mod, name, apiVersion)
		api.OldRegisterMod(mod, name, apiVersion)
		if type(mod) == "table" then mod.path = api.GetCurrentModPath() end
	end
	Isaac.RegisterMod = api.RegisterMod
	api.Mod.path = api.GetCurrentModPath()
	if dofile == nil then dofile = api.DoFile end
end
