-- Input on J510: the keyboard is controller index -2, gamepads 0-4. Index -1 is never read:
-- it is an any-device index, so a key seen there and on -2 would count twice.
local INDEXES = { -2, 0, 1, 2, 3, 4 }
local DIRECTIONS = {
	up = { ButtonAction.ACTION_UP, ButtonAction.ACTION_SHOOTUP, ButtonAction.ACTION_MENUUP },
	down = { ButtonAction.ACTION_DOWN, ButtonAction.ACTION_SHOOTDOWN, ButtonAction.ACTION_MENUDOWN },
	left = { ButtonAction.ACTION_LEFT, ButtonAction.ACTION_SHOOTLEFT, ButtonAction.ACTION_MENULEFT },
	right = { ButtonAction.ACTION_RIGHT, ButtonAction.ACTION_SHOOTRIGHT, ButtonAction.ACTION_MENURIGHT },
}
local BACK = { ButtonAction.ACTION_PILLCARD, ButtonAction.ACTION_MAP, ButtonAction.ACTION_MENUBACK }
local SELECT = { ButtonAction.ACTION_ITEM, ButtonAction.ACTION_PAUSE, ButtonAction.ACTION_MENUCONFIRM, ButtonAction.ACTION_BOMB }
local REPEAT_DELAY, REPEAT_EVERY = 20, 5 -- render frames
local BUTTON_A, BUTTON_B, BUTTON_Y = 4, 5, 7
local KEY_FIRST, KEY_LAST, BUTTON_LAST = 32, 400, 31

return function(api)
	local input = {}
	local held = { up = 0, down = 0, left = 0, right = 0 }
	local forced = {}

	local function menuConfig() return api.Config["Mod Config Menu"] or {} end

	local function onIndexes(index, test)
		if index ~= nil then return test(index) end
		for _, i in ipairs(INDEXES) do
			if test(i) then return true end
		end
		return false
	end

	-- shortcut: rejects a key whose code % 32 also reads as a gamepad button (an alias seen before J510, unobserved on J510); drop once an input probe shows no alias.
	local function keyOn(check, key, i)
		return check(key, i) and not check(key % 32, i)
	end

	function api.KeyboardTriggered(key, index)
		return onIndexes(index, function(i) return keyOn(Input.IsButtonTriggered, key, i) end)
	end

	function api.KeyboardPressed(key, index)
		return onIndexes(index, function(i) return keyOn(Input.IsButtonPressed, key, i) end)
	end

	local function firstOf(list, index, test)
		for _, item in ipairs(list) do
			if onIndexes(index, function(i) return test(item, i) end) then return item end
		end
	end

	function api.MultipleActionTriggered(list, index) return firstOf(list, index, Input.IsActionTriggered) end
	function api.MultipleActionPressed(list, index) return firstOf(list, index, Input.IsActionPressed) end
	function api.MultipleButtonTriggered(list, index) return firstOf(list, index, Input.IsButtonTriggered) end
	function api.MultipleButtonPressed(list, index) return firstOf(list, index, Input.IsButtonPressed) end
	function api.MultipleKeyboardTriggered(list, index)
		return firstOf(list, index, function(key, i) return keyOn(Input.IsButtonTriggered, key, i) end)
	end
	function api.MultipleKeyboardPressed(list, index)
		return firstOf(list, index, function(key, i) return keyOn(Input.IsButtonPressed, key, i) end)
	end

	local function force(hook, index, action, value, frames)
		forced[hook] = forced[hook] or {}
		forced[hook][index] = forced[hook][index] or {}
		if value == nil then value = true end
		forced[hook][index][action] = { value = value, untilFrame = Game():GetFrameCount() + (frames or 1) }
	end

	function api.ForceActionTriggered(index, action, value, frames)
		force(InputHook.IS_ACTION_TRIGGERED, index, action, value, frames)
	end

	function api.ForceActionPressed(index, action, value, frames)
		force(InputHook.IS_ACTION_PRESSED, index, action, value, frames)
	end

	function input.forcedValue(entity, hook, action)
		local player = entity and entity:ToPlayer()
		local byIndex = player and forced[hook] and forced[hook][player.ControllerIndex]
		local entry = byIndex and byIndex[action]
		if not entry then return nil end
		if Game():GetFrameCount() < entry.untilFrame then return entry.value end
		byIndex[action] = nil
	end

	local function anyAction(list, i, test)
		for _, action in ipairs(list) do
			if test(action, i) then return true end
		end
		return false
	end

	local function triggeredKey(i)
		for key = KEY_FIRST, KEY_LAST do
			if keyOn(Input.IsButtonTriggered, key, i) then return key end
		end
	end

	-- shortcut: the keyboard (-2) skips this rule because IsButtonPressed(4..7, -2) is unobserved on J510; recheck with an input probe.
	local function faceButtonHeld(i)
		if i < 0 then return false end
		for button = BUTTON_A, BUTTON_Y do
			if Input.IsButtonPressed(button, i) then return true end
		end
		return false
	end

	local function readIndex(i, frame)
		if faceButtonHeld(i) then
			-- Face buttons double as shoot actions, so while one is held only raw A and B count.
			frame.select = frame.select or Input.IsButtonTriggered(BUTTON_A, i)
			frame.back = frame.back or Input.IsButtonTriggered(BUTTON_B, i)
			return
		end
		for dir, actions in pairs(DIRECTIONS) do
			frame.pressed[dir] = frame.pressed[dir] or anyAction(actions, i, Input.IsActionPressed)
		end
		local back = anyAction(BACK, i, Input.IsActionTriggered) or keyOn(Input.IsButtonTriggered, Keyboard.KEY_BACKSPACE, i)
		local select = anyAction(SELECT, i, Input.IsActionTriggered)
		local key = (back or select) and triggeredKey(i)
		if key then api.Config[back and "LastBackPressed" or "LastSelectPressed"] = key end
		frame.back = frame.back or back
		frame.select = frame.select or select
	end

	-- One frame of menu input: OR over every index, so a press seen on two indexes still counts once.
	-- input.reading lets the MC_INPUT_ACTION block in menu.lua pass the menu's own action reads.
	function input.readMenu()
		local frame = { pressed = {} }
		input.reading = true
		for _, i in ipairs(INDEXES) do readIndex(i, frame) end
		input.reading = false
		for dir in pairs(held) do
			held[dir] = frame.pressed[dir] and held[dir] + 1 or 0
			local n = held[dir]
			frame[dir] = n == 1 or (n > REPEAT_DELAY and (n - REPEAT_DELAY) % REPEAT_EVERY == 0)
		end
		local resetKey = menuConfig().ResetToDefault or -1
		frame.reset = resetKey >= 0 and api.KeyboardTriggered(resetKey)
		return frame
	end

	function input.togglePressed()
		local cfg = menuConfig()
		local key, button = cfg.OpenMenuKeyboard or -1, cfg.OpenMenuController or -1
		if key >= 0 and api.KeyboardTriggered(key) then return true end
		return button >= 0 and onIndexes(nil, function(i) return Input.IsButtonTriggered(button, i) end)
	end

	function input.capture(optionType)
		if optionType == api.OptionType.KEYBIND_KEYBOARD then
			for _, i in ipairs(INDEXES) do
				local key = triggeredKey(i)
				if key then return key end
			end
			return nil
		end
		for button = 0, BUTTON_LAST do
			if onIndexes(nil, function(i) return Input.IsButtonTriggered(button, i) end) then return button end
		end
	end

	return input
end
