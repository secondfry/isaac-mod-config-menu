-- The menu's own page, named and stored under util.NAME.
local ON_OFF = { [true] = "on", [false] = "off" }
local ORDER = { [true] = "alphabetical", [false] = "load order" }

return function(api, util, menu)
	local PAGE = util.NAME

	-- The stored value changes first, then the setting takes effect at once.
	local function thenApply(setting, apply)
		local store = setting.OnChange
		setting.OnChange = function(value)
			store(value)
			apply()
		end
	end

	api.UpdateCategory(PAGE, { Info = "Settings of this menu." })
	api.AddTitle(PAGE, PAGE .. " " .. api.GetVersionString())
	api.AddSpace(PAGE)

	local openKey = api.AddKeyboardSetting(PAGE, "OpenMenuKeyboard", Keyboard.KEY_L, "Open menu", true,
		"The key that opens and closes this menu. Going back resets it to its default.")
	openKey.NoUnbind = true
	thenApply(api.AddControllerSetting(PAGE, "OpenMenuController", Controller.STICK_RIGHT, "Open menu", true,
		"The button that opens and closes this menu."), menu.moveDssOffOurStick)

	thenApply(api.AddBooleanSetting(PAGE, "HideHudInMenu", true, "Hide HUD", ON_OFF,
		"Hides the game HUD while this menu is open."), menu.applyHud)

	local resetKey = api.AddKeyboardSetting(PAGE, "ResetToDefault", Keyboard.KEY_R, "Reset to default", true,
		"Press this key on a setting to restore its default.")
	resetKey.CapturesResetKey = true -- in its own popup the reset key binds instead of resetting

	api.AddBooleanSetting(PAGE, "ShowControls", true, "Show controls", ON_OFF,
		"Shows the back and select keys in the corners, and the open-key hint when the first game of a session starts.")

	api.AddBooleanSetting(PAGE, "SortAlphabetically", true, "Mod order", ORDER,
		"Lists the other mods' pages by name, or in the order they loaded.")
end
