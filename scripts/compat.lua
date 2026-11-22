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

	-- The FilepathHelper surface; Version on this table keeps Encyclopedia's bundled copy from installing itself.
	api.KnownFilePathsByName = {}
	api.KnownFilePathsByIndex = {}
	function api.GetCurrentModPath() return api.KnownFilePathsByIndex[1] end
	function api.DoFile(path) return include(path) end
	local function no() return false end
	api.TestPath, api.IsFile, api.IsDirectory, api.IsAnm2 = no, no, no, no
	api.RegisterMod, api.OldRegisterMod = Isaac.RegisterMod, Isaac.RegisterMod
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
