-- Menu behaviour: input, navigation, editing, popups, rendering and the game callbacks.
local T = {}
local function test(name, fn) T[#T + 1] = { name, fn } end
local H = Harness
local A = ButtonAction

local function tap(press)
	press()
	H.render()
	H.render() -- a release frame, so the next tap is a fresh press
end
local function action(a, index) return function() H.pressAction(a, index or -2) end end
local function key(k, index) return function() H.pressButton(k, index or -2) end end
local DOWN, UP, LEFT, RIGHT = action(A.ACTION_DOWN), action(A.ACTION_UP), action(A.ACTION_LEFT), action(A.ACTION_RIGHT)
local SELECT, BACK = action(A.ACTION_MENUCONFIRM), action(A.ACTION_MENUBACK)

local function open()
	local api = H.loadMod()
	H.addPlayer()
	return api
end
local function show(api)
	tap(key(Keyboard.KEY_L))
	ok(api.IsVisible, "menu opened")
end

local function value(initial)
	local box = { v = initial, changes = {} }
	box.CurrentSetting = function() return box.v end
	box.OnChange = function(v)
		box.v = v
		box.changes[#box.changes + 1] = v == nil and "nil" or v
	end
	return box
end

local function row(api, cat, setting, box)
	setting.CurrentSetting, setting.OnChange = box.CurrentSetting, box.OnChange
	return api.AddSetting(cat, setting)
end

test("opening polls -2 and gamepads, never -1, and toggles once per frame", function()
	local api = open()
	H.pressButton(Keyboard.KEY_L, -2)
	H.pressButton(Keyboard.KEY_L, 0)
	H.pressButton(Controller.STICK_RIGHT, 0)
	H.render()
	eq(api.IsVisible, true, "one toggle opens")
	H.pressButton(Keyboard.KEY_L, -2)
	H.pressButton(Controller.STICK_RIGHT, 1)
	H.render()
	eq(api.IsVisible, false, "one toggle closes")
	H.render()
	ok(H.polled[-2] and H.polled[0] and H.polled[4], "keyboard and gamepads polled")
	eq(H.polled[-1], nil, "index -1 never polled")
end)

test("the controller open button counts on gamepads only, not on the keyboard index", function()
	local api = open()
	tap(key(Controller.STICK_RIGHT, -2))
	eq(api.IsVisible, false, "STICK_RIGHT on -2 does not open")
end)

test("an open Dead Sea Scrolls menu (IsOpen returns a table) blocks opening", function()
	local api = open()
	DeadSeaScrollsMenu = { IsOpen = function() return {} end }
	tap(key(Keyboard.KEY_L))
	eq(api.IsVisible, false, "stays closed over DSS")
end)

local function drawn(pattern)
	for _, t in ipairs(H.texts) do
		if t:find(pattern) then return true end
	end
	return false
end

test("another copy loaded first shows the one-menu notice", function()
	MCM = { Version = 204, MenuData = {} }
	local api = open()
	eq(MCM, api, "this copy took the globals")
	H.render()
	ok(drawn("Only one Mod Config Menu mod"), "notice drawn")
end)

test("another copy loaded later shows the notice from the next game start", function()
	local api = open()
	H.render()
	ok(not drawn("Only one Mod Config Menu mod"), "no notice alone")
	ModConfigMenu = { Version = 204 }
	H.fire(ModCallbacks.MC_POST_GAME_STARTED, false)
	H.texts = {}
	H.render()
	ok(drawn("Only one Mod Config Menu mod"), "notice drawn")
	eq(api.IsVisible, false, "menu untouched")
end)

test("an unsupported method call returns nil and shows a notice once; other unknown fields stay nil", function()
	local api = open()
	eq(MCM.SomeFlag, nil, "a non-method field reads nil")
	eq(api.IsSomething, nil, "Is-prefixed names stay nil like the IsVisible field")
	eq(rawget(api, "AddPopup"), nil, "nothing stored on the table")
	eq(MCM.AddPopup("x"), nil, "call returns nil")
	ModConfigMenu.AddPopup("y")
	local count = 0
	for _, s in ipairs(H.log) do
		if s:find("MCM.AddPopup", 1, true) then count = count + 1 end
	end
	eq(count, 1, "logged once")
	H.frame = H.frame + 400 -- a call at mod load: no render until the title screen draws
	H.render()
	ok(drawn("called MCM%.AddPopup"), "notice drawn on its first rendered frame")
	ok(drawn("github%.com/secondfry/isaac%-mod%-config%-menu/issues"), "report link drawn")
	ok(drawn("discord%.gg/5KvKaUpsvR"), "Discord link drawn")
	H.frame = H.frame + 300
	H.texts = {}
	H.render()
	ok(drawn("AddPopup"), "still shown 300 frames after it first drew")
	H.frame = H.frame + 1
	H.texts = {}
	H.render()
	ok(not drawn("AddPopup"), "notice gone after about 5 seconds")
end)

test("pages list alphabetically by default, own page first, ties by load order; off means load order", function()
	local api = open()
	for _, name in ipairs({ "b", "A", "same", "c", "Same" }) do
		api.AddSetting(name, { Type = 4, Display = name, CurrentSetting = true })
	end
	show(api)
	local function walk()
		local names = { api.CurrentCategory.Name }
		for _ = 1, 5 do
			tap(DOWN)
			names[#names + 1] = api.CurrentCategory.Name
		end
		return table.concat(names, ",")
	end
	eq(walk(), "Mod Config Menu,A,b,c,same,Same", "alphabetical")
	api.Config["Mod Config Menu"].SortAlphabetically = false
	tap(DOWN)
	eq(walk(), "Mod Config Menu,b,A,same,c,Same", "load order")
	eq(api.MenuData[2].Name, "b", "MenuData is never reordered")
end)

test("the open key is ignored when paused and the menu shuts when the game pauses", function()
	local api = open()
	H.paused = true
	tap(key(Keyboard.KEY_L))
	eq(api.IsVisible, false, "paused: stays closed")
	H.paused = false
	show(api)
	H.paused = true
	H.render()
	eq(api.IsVisible, false, "pausing closes")
end)

test("an unsafe room buzzes and keeps the menu closed, and closes it later", function()
	local api = open()
	H.roomClear = false
	tap(key(Keyboard.KEY_L))
	eq(api.IsVisible, false, "closed in uncleared room")
	eq(H.sounds[#H.sounds].id, SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, "buzz")
	eq(H.sounds[#H.sounds].volume, 0.75, "buzz volume")
	H.roomClear = true
	H.addEntity(EntityType.ENTITY_DUMMY, 0, true)
	show(api)
	H.addEntity(EntityType.ENTITY_PROJECTILE, 0, false)
	H.update()
	eq(api.IsVisible, false, "a projectile closes it")
end)

test("while open players freeze, entity input reads false and the HUD hides", function()
	local api = open()
	show(api)
	local player = Isaac.GetPlayer(0)
	H.update()
	eq(player.ControlsEnabled, false, "controls off")
	eq(player.Velocity.X, 0, "velocity zero")
	eq(H.hudVisible, false, "HUD hidden")
	eq(H.fire(ModCallbacks.MC_INPUT_ACTION, player, InputHook.IS_ACTION_TRIGGERED, A.ACTION_SHOOTLEFT), false, "blocked")
	eq(H.fire(ModCallbacks.MC_INPUT_ACTION, player, InputHook.GET_ACTION_VALUE, A.ACTION_LEFT), 0, "value 0")
	eq(H.fire(ModCallbacks.MC_INPUT_ACTION, player, InputHook.IS_ACTION_PRESSED, A.ACTION_FULLSCREEN), nil, "fullscreen passes")
	eq(H.fire(ModCallbacks.MC_INPUT_ACTION, nil, InputHook.IS_ACTION_PRESSED, A.ACTION_LEFT), nil, "non-entity read passes")
	api.CloseConfigMenu()
	eq(player.ControlsEnabled, true, "controls restored")
	eq(H.hudVisible, true, "HUD restored")
end)

test("Esc is Back while open: pause reads are blocked, the menu's own reads pass", function()
	local api = open()
	H.hookActions = true
	api.AddSetting("Esc", { Type = 4, Display = "e", CurrentSetting = true })
	show(api)
	eq(H.fire(ModCallbacks.MC_INPUT_ACTION, nil, InputHook.IS_ACTION_TRIGGERED, A.ACTION_PAUSE), false, "pause blocked")
	eq(H.fire(ModCallbacks.MC_INPUT_ACTION, nil, InputHook.IS_ACTION_PRESSED, A.ACTION_MENUBACK), false, "menu back blocked")
	eq(H.fire(ModCallbacks.MC_INPUT_ACTION, nil, InputHook.GET_ACTION_VALUE, A.ACTION_PAUSE), 0, "pause value 0")
	eq(H.fire(ModCallbacks.MC_INPUT_ACTION, nil, InputHook.IS_ACTION_TRIGGERED, A.ACTION_FULLSCREEN), nil, "fullscreen untouched")
	tap(DOWN)
	tap(RIGHT)
	eq(api.GetCurrentFocus().option, 1, "in the rows")
	tap(BACK)
	eq(api.GetCurrentFocus().option, nil, "Esc (menu back) still reaches the menu")
	ok(api.IsVisible, "still open")
	api.CloseConfigMenu()
	eq(H.fire(ModCallbacks.MC_INPUT_ACTION, nil, InputHook.IS_ACTION_TRIGGERED, A.ACTION_PAUSE), nil, "closed: pause passes")
end)

test("a dependent's failing Display does not stop later mods' render callbacks", function()
	local api = open()
	api.AddSetting("Broken", { Type = 4, CurrentSetting = true, Display = function() error("broken display") end })
	local laterRan = false
	Isaac.AddCallback({}, ModCallbacks.MC_POST_RENDER, function() laterRan = true end)
	show(api)
	tap(DOWN)
	laterRan = false
	H.render()
	ok(laterRan, "a later-registered MC_POST_RENDER callback still runs")
	ok(api.IsVisible, "menu still open")
end)

test("category list wraps; rows skip SPACE, NoCursorHere, unknown types and Display-less rows", function()
	local api = open()
	local a, b = value(false), value(false)
	api.AddText("Nav", "label")
	row(api, "Nav", { Type = 4, Display = "a" }, a)
	api.AddSpace("Nav")
	api.AddSetting("Nav", { Type = 99, Display = "unknown" })
	api.AddSetting("Nav", { Type = 4 })
	api.AddSetting("Nav", { Type = 4, Display = "skip", NoCursorHere = function() return true end })
	row(api, "Nav", { Type = 4, Display = "b" }, b)
	show(api)
	tap(UP)
	eq(api.GetCurrentFocus().category, 2, "up from the first category wraps to the last")
	tap(RIGHT)
	eq(api.GetCurrentFocus().option, 2, "Uncategorized-only opens straight into the first selectable row")
	tap(DOWN)
	eq(api.GetCurrentFocus().option, 7, "down skips to b")
	tap(DOWN)
	eq(api.GetCurrentFocus().option, 2, "down wraps to a")
	tap(UP)
	eq(api.GetCurrentFocus().option, 7, "up from the first row wraps to the last")
	tap(key(Keyboard.KEY_BACKSPACE))
	eq(api.GetCurrentFocus().option, nil, "back leaves the rows")
	eq(api.Config.LastBackPressed, Keyboard.KEY_BACKSPACE, "the keyboard back key is remembered for the corner hint")
	tap(BACK)
	eq(api.IsVisible, false, "back on the category list closes")
end)

test("tabs: left/right wrap, down enters, up leaves", function()
	local api = open()
	for _, name in ipairs({ "One", "Two", "Three", "Four" }) do
		api.AddSetting("Tabs", name, { Type = 4, Display = name, CurrentSetting = true })
	end
	show(api)
	tap(DOWN)
	tap(SELECT)
	eq(api.GetCurrentFocus().option, nil, "on the tab bar")
	tap(LEFT)
	eq(api.GetCurrentFocus().subcategory, 4, "left wraps")
	tap(RIGHT)
	eq(api.GetCurrentFocus().subcategory, 1, "right wraps")
	tap(DOWN)
	eq(api.GetCurrentFocus().option, 1, "down enters rows")
	tap(LEFT)
	ok(api.CurrentOption ~= nil, "left on a BOOLEAN edits instead of leaving")
	tap(BACK)
	tap(UP)
	tap(DOWN)
	eq(api.GetCurrentFocus().category, 1, "up left the tab bar for the category list")
end)

test("BOOLEAN toggles on Left, Right and Select; Reset restores Default; changes plop", function()
	local api = open()
	local box = value(false)
	row(api, "Edit", { Type = 4, Display = "b", Default = true }, box)
	show(api)
	tap(DOWN)
	tap(RIGHT)
	tap(RIGHT)
	eq(box.v, true, "right toggles")
	tap(LEFT)
	eq(box.v, false, "left toggles")
	tap(SELECT)
	eq(box.v, true, "select toggles")
	box.v = false
	tap(key(Keyboard.KEY_R))
	eq(box.v, true, "reset key restores Default")
	eq(H.sounds[#H.sounds].id, SoundEffect.SOUND_PLOP, "plop")
	local changes = #box.changes
	tap(key(Keyboard.KEY_R))
	eq(#box.changes, changes, "a row already at its default gets no OnChange")
end)

test("NUMBER wraps or clamps and rounds; SCROLL clamps at 0-10", function()
	local api = open()
	local wrapBox, clampBox, decimalBox, scrollBox = value(2), value(2), value(0.2), value(10)
	row(api, "Num", { Type = 5, Display = "w", Minimum = 0, Maximum = 2 }, wrapBox)
	row(api, "Num", { Type = 5, Display = "c", Minimum = 0, Maximum = 2, NoLoopFromMaxMin = true }, clampBox)
	row(api, "Num", { Type = 5, Display = "d", Minimum = 0, Maximum = 1, ModifyBy = 0.1 }, decimalBox)
	row(api, "Num", { Type = 3, Display = "s $scroll10" }, scrollBox)
	show(api)
	tap(DOWN)
	tap(RIGHT)
	tap(RIGHT)
	eq(wrapBox.v, 0, "max wraps to min")
	tap(LEFT)
	eq(wrapBox.v, 2, "min wraps to max")
	tap(DOWN)
	tap(RIGHT)
	eq(clampBox.v, 2, "NoLoopFromMaxMin clamps")
	tap(DOWN)
	tap(RIGHT)
	eq(decimalBox.v, 0.3, "decimal step rounds to 3 places")
	tap(DOWN)
	tap(RIGHT)
	eq(scrollBox.v, 10, "scroll clamps at 10")
	tap(LEFT)
	eq(scrollBox.v, 9, "scroll steps down")
end)

test("plain CurrentSetting is overwritten without OnChange", function()
	local api = open()
	local called = false
	local s = api.AddSetting("Plain", { Type = 4, Display = "p", CurrentSetting = false, OnChange = function() called = true end })
	show(api)
	tap(DOWN)
	tap(RIGHT)
	tap(RIGHT)
	eq(s.CurrentSetting, true, "field overwritten")
	eq(called, false, "OnChange not called")
end)

test("keybind popup: capture, buzz on menu keys, unbind calls OnChange(nil), NoUnbind resets", function()
	local api = open()
	local raw, locked = value(-1), value(76)
	row(api, "Keys", { Type = 6, Display = "raw", Popup = "press" }, raw)
	row(api, "Keys", { Type = 6, Display = "locked", NoUnbind = true, Default = 76 }, locked)
	local helper = api.AddKeyboardSetting("Keys", "helperKey", 70, "Helper")
	show(api)
	tap(DOWN)
	tap(RIGHT)
	tap(RIGHT)
	ok(api.IsVisible, "still open")
	tap(DOWN)
	eq(raw.changes[1], nil, "a menu key does not bind")
	eq(H.sounds[#H.sounds].id, SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, "menu key buzzes")
	tap(key(Keyboard.KEY_K))
	eq(raw.v, Keyboard.KEY_K, "captured K")
	tap(RIGHT)
	tap(BACK)
	eq(raw.changes[#raw.changes], "nil", "unbinding a raw row calls OnChange(nil)")
	tap(DOWN)
	tap(RIGHT)
	tap(BACK)
	eq(locked.v, 76, "NoUnbind goes back to Default")
	tap(DOWN)
	tap(RIGHT)
	tap(BACK)
	eq(api.Config.Keys.helperKey, -1, "a helper row stores -1")
	eq(helper.Display(), "Helper: None", "shown unbound")
end)

test("the reset-key row binds the reset key instead of resetting", function()
	local api = open()
	show(api)
	tap(RIGHT)
	local focus = api.GetCurrentFocus()
	local options = api.MenuData[1].Subcategories[1].Options
	local resetRow
	for i, opt in ipairs(options) do
		if opt.Attribute == "ResetToDefault" then resetRow = i end
	end
	for _ = focus.option, resetRow - 1 do tap(DOWN) end
	eq(api.CurrentOption.Attribute, "ResetToDefault", "on the reset row")
	tap(SELECT)
	tap(key(Keyboard.KEY_T))
	eq(api.Config["Mod Config Menu"].ResetToDefault, Keyboard.KEY_T, "rebound to T")
	tap(SELECT)
	tap(key(Keyboard.KEY_T))
	eq(api.Config["Mod Config Menu"].ResetToDefault, Keyboard.KEY_T, "T binds itself in its own popup")
end)

test("Restart rows warn once changed", function()
	local api = open()
	local box = value(false)
	row(api, "Warn", { Type = 4, Display = "r", Restart = true }, box)
	show(api)
	tap(DOWN)
	tap(RIGHT)
	tap(RIGHT)
	local found = false
	for _, t in ipairs(H.texts) do
		if t:find("restart") or t:find("Restart") then found = true end
	end
	ok(found, "warning text drawn")
	tap(SELECT)
	eq(box.v, true, "select closed the popup without another change")
end)

test("the restart warning stays on screen after the menu closes", function()
	local api = open()
	row(api, "Warn", { Type = 4, Display = "r", Restart = true }, value(false))
	show(api)
	tap(DOWN)
	tap(RIGHT)
	tap(RIGHT)
	tap(SELECT)
	api.CloseConfigMenu()
	H.texts = {}
	H.render()
	ok(drawn("Restart the game"), "warning drawn while closed")
end)

test("a popup closes on Back even when Select arrives in the same frame", function()
	local api = open()
	local selected = false
	api.AddSetting("Pop", { Type = 1, Display = "p", Popup = "sure?", OnSelect = function() selected = true end })
	show(api)
	tap(DOWN)
	tap(RIGHT)
	tap(RIGHT)
	H.pressAction(A.ACTION_MENUBACK, -2)
	H.pressAction(A.ACTION_MENUCONFIRM, -2)
	H.render()
	eq(selected, false, "Back wins: no OnSelect")
	tap(RIGHT)
	tap(SELECT)
	eq(selected, true, "Select alone confirms")
end)

test("closing the menu saves", function()
	local api = open()
	show(api)
	api.Config["Mod Config Menu"].ShowControls = false
	api.CloseConfigMenu()
	ok(H.modData and H.modData:find('"ShowControls":false'), "saved on close")
end)

test("a new floor saves only while a game's settings are loaded", function()
	open()
	H.fire(ModCallbacks.MC_POST_NEW_LEVEL)
	eq(H.modData, nil, "no save before the game's load")
	H.fire(ModCallbacks.MC_POST_GAME_STARTED, true)
	H.fire(ModCallbacks.MC_POST_NEW_LEVEL)
	ok(H.modData ~= nil, "saved after the load")
	H.fire(ModCallbacks.MC_PRE_GAME_EXIT, true)
	H.modData = nil
	H.fire(ModCallbacks.MC_POST_NEW_LEVEL)
	eq(H.modData, nil, "no save after exit until the next game starts")
end)

test("Display runs once per frame for visible rows only, wherever the cursor is", function()
	local api = open()
	local calls = {}
	for i = 1, 30 do
		api.AddSetting("Many", { Type = 4, CurrentSetting = true, Display = function(cursorHere, inOptions, pos)
			calls[i] = (calls[i] or 0) + 1
			ok(pos.X ~= nil, "row position is a Vector")
			return "row " .. i
		end })
	end
	show(api)
	tap(DOWN)
	for i = 1, 30 do calls[i] = nil end
	H.render()
	H.render()
	for i = 1, 10 do eq(calls[i], 2, "visible row " .. i) end
	for i = 11, 30 do eq(calls[i], nil, "hidden row " .. i) end
end)

test("menu renders every built-in row and popup without errors", function()
	local api = open()
	show(api)
	tap(RIGHT)
	for _ = 1, 12 do
		tap(SELECT)
		tap(BACK)
		tap(DOWN)
	end
	ok(#H.texts > 0, "text drawn")
end)

test("game start loads, a new run saves, exit saves", function()
	local api = open()
	H.fire(ModCallbacks.MC_POST_GAME_STARTED, false)
	ok(H.modData ~= nil, "new run saved")
	H.modData = '{"Mod Config Menu":{"ShowControls":false}}'
	H.fire(ModCallbacks.MC_POST_GAME_STARTED, true)
	eq(api.Config["Mod Config Menu"].ShowControls, false, "continue loaded")
	api.Config["Mod Config Menu"].ShowControls = true
	H.fire(ModCallbacks.MC_PRE_GAME_EXIT, true)
	ok(H.modData:find('"ShowControls":true'), "exit saved")
end)

test("a game on a slot with no save starts from the defaults", function()
	local api = open()
	api.Config["Mod Config Menu"].ShowControls = false
	H.modData = nil
	H.fire(ModCallbacks.MC_POST_GAME_STARTED, false)
	eq(api.Config["Mod Config Menu"].ShowControls, true, "back at default")
end)

test("first game start shows the open-key hint", function()
	local api = open()
	H.fire(ModCallbacks.MC_POST_GAME_STARTED, false)
	H.texts = {}
	H.render()
	local found = false
	for _, t in ipairs(H.texts) do
		if t:find("Press L") then found = true end
	end
	ok(found, "hint drawn")
	for _ = 1, 120 do H.update() end
	H.texts = {}
	H.render()
	eq(#H.texts, 0, "hint gone after 120 updates")
end)

return T
