-- Legacy API members and deprecated globals old dependents still read; each forwards with a one-time notice.
-- Unknown method-like members return a no-op stub that names the call on screen once per session.
-- The stub returns nil, not a dummy table: a truthy dummy from a getter would hide the missing feature from the caller.
-- Lua cannot tell MCM.X from MCM.X(), so only verb-named keys get a stub: other fields still read nil for `if MCM.X then` checks.
local METHOD_VERBS = {
	"Add", "Get", "Set", "Remove", "Update", "Open", "Close", "Toggle", "Show", "Hide", "Register",
	"Reset", "Save", "Load", "Draw", "Create", "Change", "Clear", "Delete", "Insert", "Refresh",
}

local function looksLikeMethod(key)
	if type(key) ~= "string" then return false end
	for _, verb in ipairs(METHOD_VERBS) do
		if key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("[%u%d_]") then return true end
	end
	return false
end

return function(api, util, menu)
	local function stub(key)
		return function()
			local line = "A mod called MCM." .. key .. ", which is not supported yet."
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
			if not make then return looksLikeMethod(key) and stub(key) or nil end
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
