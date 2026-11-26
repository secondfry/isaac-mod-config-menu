-- Legacy API members and deprecated globals old dependents still read; each forwards with a one-time notice.
-- Unknown members return a no-op stub that names the call on screen once per session.
-- The stub returns nil, not a dummy table: a truthy dummy from a getter would hide the missing feature from the caller.
-- shortcut: Lua cannot tell MCM.X from MCM.X(), so `if MCM.Unknown then` now passes; filter names if a mod is seen relying on that.
-- Public fields that are nil while nothing is focused: mods test them with `if MCM.CurrentOption then`.
local NIL_FIELDS = { CurrentCategory = true, CurrentSubcategory = true, CurrentOption = true }

return function(api, util, menu)
	local function stub(key)
		return function()
			local line = "A mod called MCM." .. tostring(key) .. ", which is not supported yet."
			if util.warnOnce("unsupported " .. key, line .. " " .. util.REPORT) then menu.noticeUnsupported(line) end
			return nil
		end
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
			if NIL_FIELDS[key] then return nil end
			if not make then return stub(key) end
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
