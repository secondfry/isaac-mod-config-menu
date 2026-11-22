-- Key and button names the player sees, and the popup text for binding them.
local CONTROLLER = {
	DPAD_LEFT = 0, DPAD_RIGHT = 1, DPAD_UP = 2, DPAD_DOWN = 3,
	BUTTON_A = 4, BUTTON_B = 5, BUTTON_X = 6, BUTTON_Y = 7,
	BUMPER_LEFT = 8, TRIGGER_LEFT = 9, STICK_LEFT = 10,
	BUMPER_RIGHT = 11, TRIGGER_RIGHT = 12, STICK_RIGHT = 13,
	BUTTON_BACK = 14, BUTTON_START = 15,
}
local SIDE_LAST = { BUMPER = true, TRIGGER = true, STICK = true }

return function(api, util)
	local T = api.OptionType
	if Controller == nil then Controller = CONTROLLER end

	api.KeyboardToString = {}
	for name, code in pairs(Keyboard) do
		api.KeyboardToString[code] = (name:gsub("^KEY_", ""):gsub("_", " "))
	end

	api.ControllerToString = {}
	for name, code in pairs(CONTROLLER) do
		local label = name:gsub("^BUTTON_", ""):gsub("^(%u+)_(%u+)$", function(kind, side)
			if SIDE_LAST[kind] then return side .. " " .. kind end
		end)
		api.ControllerToString[code] = (label:gsub("_", " "))
	end

	local keys = {}
	local isController = function(optionType) return optionType == T.KEYBIND_CONTROLLER end

	function keys.deviceName(optionType)
		return isController(optionType) and "controller" or "keyboard"
	end

	function keys.keyName(optionType, value)
		if type(value) ~= "number" or value < 0 then return "None" end
		if isController(optionType) then return api.ControllerToString[value] or "Unknown button" end
		return api.KeyboardToString[value] or "Unknown key"
	end

	function keys.bindPopupText(setting)
		local kind = setting.Type
		local lines = {
			"Press a " .. (isController(kind) and "button" or "key") .. " on your " .. keys.deviceName(kind) .. " to bind it.",
			"",
		}
		local current = util.Resolve(setting.CurrentSetting)
		if type(current) == "number" and current >= 0 then
			lines[#lines + 1] = 'Now bound to "' .. keys.keyName(kind, current) .. '".'
			lines[#lines + 1] = ""
		end
		local back = isController(kind) and "BACK" or (api.KeyboardToString[api.Config.LastBackPressed] or "ESCAPE")
		lines[#lines + 1] = "Press " .. back .. " to " .. (setting.NoUnbind and "reset it to its default." or "clear it.")
		return table.concat(lines, "$newline")
	end

	return keys
end
