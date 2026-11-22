-- Opening and closing, room safety, frozen players, saving, and the game callbacks that drive the menu.
local HINT_UPDATES, HINT_FADE = 120, 60
local COMMANDS = { modconfigmenu = true, modconfig = true, mcm = true, mc = true }
-- Dead Sea Scrolls gamepad toggle: 1 either stick, 2 left only, 3 right only; 10 and 13 are the stick buttons.
local DSS_INCLUDES = { [10] = { [1] = true, [2] = true }, [13] = { [1] = true, [3] = true } }
local DSS_OTHER_STICK = { [10] = 3, [13] = 2 }
local PAUSE_ACTIONS = { [ButtonAction.ACTION_PAUSE] = true, [ButtonAction.ACTION_MENUBACK] = true }

return function(api, mod, input, nav, render)
	api.IsVisible = false
	api.ControlsEnabled = true
	api.IgnoreActiveEnemies = { [EntityType.ENTITY_DUMMY] = { [-1] = true } } -- Potato Dummy
	local frozen = {}
	local hudWasVisible = true
	local hintTimer, hintShown = 0, false

	local function menuConfig() return api.Config["Mod Config Menu"] or {} end

	local function applyHud()
		if not api.IsVisible then return end
		Game():GetHUD():SetVisible(hudWasVisible and not menuConfig().HideHudInMenu)
	end

	local function otherMenuOpen()
		local dss = DeadSeaScrollsMenu
		if AwaitingTextInput or CustomConsoleOpen then return true end
		return dss ~= nil and dss.IsOpen ~= nil and dss.IsOpen() == true
	end

	function api.GetIsPaused()
		return otherMenuOpen() or Game():IsPaused()
	end

	local function ignored(entity)
		local byVariant = api.IgnoreActiveEnemies[entity.Type]
		return byVariant ~= nil and (byVariant[entity.Variant] or byVariant[-1]) == true
	end

	function api.RoomIsSafe()
		if not Game():GetRoom():IsClear() then return false end
		for _, entity in ipairs(Isaac.GetRoomEntities()) do
			if entity.Type == EntityType.ENTITY_PROJECTILE or entity.Type == EntityType.ENTITY_BOMB then return false end
			if entity:IsActiveEnemy(false) and not entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) and not ignored(entity) then
				return false
			end
		end
		return true
	end

	-- Players are re-fetched every time: a kept EntityPlayer can outlive its entity.
	local function eachPlayer(fn)
		for i = 0, Game():GetNumPlayers() - 1 do fn(Isaac.GetPlayer(i)) end
	end

	local function freezePlayers()
		eachPlayer(function(player)
			local key = GetPtrHash(player)
			local pos = player.Position
			frozen[key] = frozen[key] or { position = Vector(pos.X, pos.Y), controls = player.ControlsEnabled }
			player.ControlsEnabled = false
			player.Velocity = Vector(0, 0)
			player.Position = frozen[key].position
		end)
	end

	local function releasePlayers()
		eachPlayer(function(player)
			local entry = frozen[GetPtrHash(player)]
			if entry then player.ControlsEnabled = entry.controls end
		end)
		frozen = {}
	end

	function api.OpenConfigMenu()
		if api.IsVisible then return end
		if not api.RoomIsSafe() then return nav.buzz() end
		api.IsVisible, api.ControlsEnabled = true, false
		hudWasVisible = Game():GetHUD():IsVisible()
		applyHud()
	end

	function api.CloseConfigMenu()
		if not api.IsVisible then return end
		api.IsVisible, api.ControlsEnabled = false, true
		nav.reset()
		Game():GetHUD():SetVisible(hudWasVisible)
		releasePlayers()
	end

	function api.ToggleConfigMenu()
		if api.IsVisible then api.CloseConfigMenu() else api.OpenConfigMenu() end
	end

	local function load()
		if mod:HasData() then api.LoadSave(mod:LoadData()) end
	end

	local function save()
		local ok, data = pcall(api.GetSave)
		if ok then return mod:SaveData(data) end
		Isaac.DebugString("[Config Menu] settings not saved: " .. tostring(data))
	end

	local function moveDssOffOurStick()
		local dss = DeadSeaScrollsMenu
		if not (dss and dss.GetGamepadToggleSetting and dss.SaveGamepadToggleSetting) then return end
		local stick = menuConfig().OpenMenuController
		local includes = DSS_INCLUDES[stick]
		if includes and includes[dss.GetGamepadToggleSetting()] then dss.SaveGamepadToggleSetting(DSS_OTHER_STICK[stick]) end
	end

	-- shortcut: whether blocking ACTION_PAUSE in onInputAction stops Esc pausing is unobserved on J510; if the game
	-- still pauses right after the menu's own Back press, the menu waits out that pause instead of closing.
	-- Drop pauseFromBack once an in-game run shows Esc no longer pauses while the menu is open.
	local renderCount, lastBackRender, pauseFromBack = 0, -10, false

	local function keepThroughPause()
		if not api.IsVisible or not Game():IsPaused() or otherMenuOpen() then return false end
		pauseFromBack = pauseFromBack or renderCount - lastBackRender <= 2
		return pauseFromBack
	end

	local function onRender()
		renderCount = renderCount + 1
		if keepThroughPause() then return end
		pauseFromBack = false
		local paused = api.GetIsPaused()
		if paused then api.CloseConfigMenu() end
		if not paused and not nav.popup and input.togglePressed() then
			api.ToggleConfigMenu()
		elseif api.IsVisible then
			local frame = input.readMenu()
			if frame.back then lastBackRender = renderCount end
			if nav.step(frame, input.capture) == "close" then api.CloseConfigMenu() end
		end
		if api.IsVisible then return render.menu() end
		if hintTimer > 0 then render.hint(math.min(1, hintTimer / HINT_FADE)) end
	end

	local function onUpdate()
		if hintTimer > 0 then hintTimer = hintTimer - 1 end
		if not api.IsVisible then return end
		if not api.RoomIsSafe() then
			api.CloseConfigMenu()
			return nav.buzz()
		end
		freezePlayers()
	end

	-- Blocks entity-bound reads, plus the entity-less pause checks so Esc acts as Back instead of pausing;
	-- the menu's own reads pass while input.reading is set.
	local function onInputAction(_, entity, hook, action)
		local forced = input.forcedValue(entity, hook, action)
		if forced ~= nil then return forced end
		if not api.IsVisible or input.reading then return nil end
		if action == ButtonAction.ACTION_FULLSCREEN or action == ButtonAction.ACTION_CONSOLE then return nil end
		if entity == nil and not PAUSE_ACTIONS[action] then return nil end
		if hook == InputHook.GET_ACTION_VALUE then return 0 end
		return false
	end

	local function onGameStarted(_, continued)
		load()
		nav.rerunWarning = false
		moveDssOffOurStick()
		if not hintShown then
			hintShown = true
			if menuConfig().ShowControls then hintTimer = HINT_UPDATES end
		end
		if not continued then save() end
	end

	local function onGameExit()
		api.CloseConfigMenu()
		save()
	end

	local function onCommand(_, command)
		if COMMANDS[command:lower()] then api.ToggleConfigMenu() end
	end

	mod:AddCallback(ModCallbacks.MC_POST_RENDER, onRender)
	mod:AddCallback(ModCallbacks.MC_POST_UPDATE, onUpdate)
	mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, onInputAction)
	mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, onGameStarted)
	mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, onGameExit)
	mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, save)
	mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, onCommand)

	return { applyHud = applyHud, load = load }
end
