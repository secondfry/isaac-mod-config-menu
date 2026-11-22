-- The menu's own page. Its Config key stays "Mod Config Menu": EID reads HideHudInMenu there.
local CONFIG_KEY = "Mod Config Menu"
local PAGE_NAME = "Config Menu"
local ON_OFF = { [true] = "on", [false] = "off" }

return function(api, applyHud)
	api.UpdateCategory(CONFIG_KEY, { Info = "Settings of this menu." })
	api.AddTitle(CONFIG_KEY, PAGE_NAME .. " " .. api.GetVersionString())
	api.AddSpace(CONFIG_KEY)

	local openKey = api.AddKeyboardSetting(CONFIG_KEY, "OpenMenuKeyboard", Keyboard.KEY_L, "Open menu", true,
		"The key that opens and closes this menu. Going back resets it to its default.")
	openKey.NoUnbind = true
	api.AddControllerSetting(CONFIG_KEY, "OpenMenuController", Controller.STICK_RIGHT, "Open menu", true,
		"The button that opens and closes this menu.")

	local hideHud = api.AddBooleanSetting(CONFIG_KEY, "HideHudInMenu", true, "Hide HUD", ON_OFF,
		"Hides the game HUD while this menu is open.")
	local storeHideHud = hideHud.OnChange
	hideHud.OnChange = function(value)
		storeHideHud(value)
		applyHud()
	end

	local resetKey = api.AddKeyboardSetting(CONFIG_KEY, "ResetToDefault", Keyboard.KEY_R, "Reset to default", true,
		"Press this key on a setting to restore its default.")
	resetKey.CapturesResetKey = true -- in its own popup the reset key binds instead of resetting

	api.AddBooleanSetting(CONFIG_KEY, "ShowControls", true, "Show controls", ON_OFF,
		"Shows the back and select keys in the corners, and the open-key hint when a game starts.")

	-- Renamed after registering, so the helpers keep storing under CONFIG_KEY.
	api.UpdateCategory(CONFIG_KEY, { Name = PAGE_NAME })
end
