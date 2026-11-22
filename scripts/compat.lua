-- Legacy API members and deprecated globals old dependents still read; each forwards with a one-time notice.
return function(api, util)
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
			util.deprecated("ModConfigMenu." .. key, "the game API directly")
			return make()
		end,
	})

	local function deprecated(name, target, replacement)
		return setmetatable({}, {
			__index = function(_, key)
				util.deprecated(name, replacement)
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
