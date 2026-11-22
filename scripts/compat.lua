-- Legacy globals and members old dependents still read; each points at the one API table.
return function(api)
	local warned = {}
	local function warnOnce(name, replacement)
		if warned[name] then return end
		warned[name] = true
		print("[Config Menu] " .. name .. " is deprecated, use " .. replacement)
	end

	local LEGACY_MEMBERS = {
		Game = function() return Game() end,
		Seeds = function() return Game():GetSeeds() end,
		Level = function() return Game():GetLevel() end,
		Room = function() return Game():GetRoom() end,
		SFX = function() return SFXManager() end,
		VECTOR_ZERO = function() return Vector(0, 0) end,
		VECTOR_ONE = function() return Vector(1, 1) end,
		COLOR_DEFAULT = function() return Color(1, 1, 1, 1, 0, 0, 0) end,
		COLOR_HALF = function() return Color(1, 1, 1, 0.5, 0, 0, 0) end,
		KCOLOR_DEFAULT = function() return KColor(1, 1, 1, 1) end,
		KCOLOR_HALF = function() return KColor(1, 1, 1, 0.5) end,
	}
	setmetatable(api, {
		__index = function(_, key)
			local make = LEGACY_MEMBERS[key]
			if not make then return nil end
			warnOnce("ModConfigMenu." .. key, "the game API directly")
			return make()
		end,
	})

	-- The FilepathHelper surface; Version on this table keeps Encyclopedia's bundled copy from installing itself,
	-- so this table owes its contract: every mod registered later carries a string `path` (Encyclopedia concatenates it).
	api.KnownFilePathsByName = {}
	api.KnownFilePathsByIndex = {}

	-- require("") fails listing each search pattern as "no file '<pattern>'"; the second is the loading mod's root.
	-- shortcut: the second-entry rule is taken from FilepathHelper's in-game behaviour, not observed here; with no such entry
	-- the path is "" so concatenation stays safe; probe package.path in game if a mod reports a wrong path.
	local function loadingModPath()
		local _, message = pcall(require, "")
		local found = 0
		for pattern in tostring(message):gmatch("no file '([^']*)'") do
			found = found + 1
			if found == 2 then return (pattern:gsub("\\", "/"):gsub("%.lua$", "")) end
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
		local registered, message = pcall(api.OldRegisterMod, mod, name, apiVersion)
		if not registered then error(message, 2) end
		if type(mod) == "table" then mod.path = api.GetCurrentModPath() end
	end
	Isaac.RegisterMod = api.RegisterMod
	api.Mod.path = api.GetCurrentModPath()
	if dofile == nil then dofile = api.DoFile end

	ScreenHelper, InputHelper, FilepathHelper = api, api, api
	ModConfigMenuData = api.MenuData

	local function deprecated(name, target, replacement)
		return setmetatable({}, {
			__index = function(_, key)
				warnOnce(name, replacement)
				return target[key]
			end,
		})
	end
	ModConfigMenuController = deprecated("ModConfigMenuController", Controller, "Controller")
	ModConfigMenuKeyboardToString = deprecated("ModConfigMenuKeyboardToString", api.KeyboardToString, "InputHelper.KeyboardToString")
	ModConfigMenuControllerToString = deprecated("ModConfigMenuControllerToString", api.ControllerToString, "InputHelper.ControllerToString")
	ModConfigMenuPopupGfx = deprecated("ModConfigMenuPopupGfx", api.PopupGfx, "ModConfigMenu.PopupGfx")
	ModConfigMenuOptionType = deprecated("ModConfigMenuOptionType", api.OptionType, "ModConfigMenu.OptionType")
end
