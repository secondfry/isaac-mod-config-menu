-- A minimal vanilla Isaac API, enough to load the mod and drive it outside the game.
-- Expects ROOT (repo, trailing slash) and GAME_SCRIPTS (game resources/scripts, trailing slash).
-- enums.lua builds TearFlags with BitSet128 and adds constants to these engine classes.
function BitSet128(l, h) return { l = l, h = h } end
ItemConfig, RoomDescriptor = {}, {}
dofile(GAME_SCRIPTS .. "enums.lua")
package.path = ROOT .. "?.lua;" .. package.path
package.preload.json = function() return dofile(GAME_SCRIPTS .. "json.lua") end
REPENTANCE, REPENTANCE_PLUS = true, true

local H = {
	callbacks = {}, modData = nil, frame = 0, paused = false, roomClear = true,
	entities = {}, players = {}, hudVisible = true, sounds = {}, texts = {}, log = {},
	pressed = {}, triggered = {}, actionsPressed = {}, actionsTriggered = {}, polled = {},
}
Harness = H

function include(name)
	return dofile(ROOT .. (name:gsub("%.", "/")) .. ".lua")
end

local VectorMeta = {}
VectorMeta.__index = VectorMeta
VectorMeta.__add = function(a, b) return Vector(a.X + b.X, a.Y + b.Y) end
VectorMeta.__sub = function(a, b) return Vector(a.X - b.X, a.Y - b.Y) end
VectorMeta.__mul = function(a, b)
	if type(a) == "number" then return Vector(a * b.X, a * b.Y) end
	if type(b) == "number" then return Vector(a.X * b, a.Y * b) end
	return Vector(a.X * b.X, a.Y * b.Y)
end
VectorMeta.__div = function(a, b) return Vector(a.X / b, a.Y / b) end
function Vector(x, y) return setmetatable({ X = x, Y = y }, VectorMeta) end
function Color(r, g, b, a, ro, go, bo) return { R = r, G = g, B = b, A = a or 1 } end
function KColor(r, g, b, a) return { Red = r, Green = g, Blue = b, Alpha = a } end

function Sprite()
	local s = { Scale = Vector(1, 1), Color = Color(1, 1, 1, 1) }
	function s:Load(path) self.path = path end
	function s:SetFrame(anim, frame) self.anim, self.frameNum = anim, frame end
	function s:Play(anim) self.anim = anim end
	function s:ReplaceSpritesheet(layer, path) self.sheet = path end
	function s:LoadGraphics() end
	function s:Render(pos) H.drawnSprites = (H.drawnSprites or 0) + 1 end
	return s
end

function Font()
	local f = {}
	function f:Load(path) self.path = path end
	function f:DrawStringUTF8(str, x, y) assert(type(str) == "string", "DrawStringUTF8 needs a string") H.texts[#H.texts + 1] = str end
	function f:GetStringWidthUTF8(str) return #str * 5 end
	return f
end

local sfx = {}
function sfx:Play(id, volume) H.sounds[#H.sounds + 1] = { id = id, volume = volume } end
function SFXManager() return sfx end

Options = { HUDOffset = 0.7, ChargeBars = false, AnnouncerVoiceMode = 0 }

function GetPtrHash(e) return e.hash end

local function key(code, index)
	H.polled[index] = true
	return code .. "@" .. index
end

Input = {
	IsButtonPressed = function(b, i) return H.pressed[key(b, i)] == true end,
	IsButtonTriggered = function(b, i) return H.triggered[key(b, i)] == true end,
	IsActionPressed = function(a, i) return H.actionsPressed[key(a, i)] == true end,
	IsActionTriggered = function(a, i)
		-- With H.hookActions, entity-less reads pass through MC_INPUT_ACTION as the engine may do (unobserved).
		local hooked = H.hookActions and H.fire(ModCallbacks.MC_INPUT_ACTION, nil, InputHook.IS_ACTION_TRIGGERED, a)
		if hooked ~= nil then return hooked end
		return H.actionsTriggered[key(a, i)] == true
	end,
}

-- Presses for one frame: a raw button/key, or an action, on one controller index.
function H.pressButton(code, index) H.pressed[key(code, index)], H.triggered[key(code, index)] = true, true end
function H.pressAction(action, index) H.actionsPressed[key(action, index)], H.actionsTriggered[key(action, index)] = true, true end
function H.clearInput() H.pressed, H.triggered, H.actionsPressed, H.actionsTriggered = {}, {}, {}, {} end

local hud = {
	SetVisible = function(_, v) H.hudVisible = v end,
	IsVisible = function() return H.hudVisible end,
}
local room = {
	IsClear = function() return H.roomClear end,
}
local game = {}
function game:GetHUD() return hud end
function game:GetRoom() return room end
function game:IsPaused() return H.paused end
function game:GetNumPlayers() return #H.players end
function game:GetPlayer(i) return H.players[i + 1] end
function game:GetFrameCount() return H.frame end
function Game() return game end

function H.addPlayer(controllerIndex)
	local p = { Position = Vector(100, 100), Velocity = Vector(3, 4), ControlsEnabled = true, ControllerIndex = controllerIndex or -2, hash = #H.players + 1 }
	function p:ToPlayer() return self end
	H.players[#H.players + 1] = p
	return p
end

function H.addEntity(type, variant, active, flags)
	local e = { Type = type, Variant = variant or 0 }
	function e:IsActiveEnemy() return active == true end
	function e:HasEntityFlags(f) return ((flags or 0) & f) ~= 0 end
	H.entities[#H.entities + 1] = e
	return e
end

Isaac = {}
function Isaac.RegisterMod(mod, name) mod.Name = name end
function Isaac.AddPriorityCallback(mod, id, priority, fn, param)
	H.callbacks[id] = H.callbacks[id] or {}
	table.insert(H.callbacks[id], { Mod = mod, Function = fn, Priority = priority, Param = param })
end
function Isaac.AddCallback(mod, id, fn, param) Isaac.AddPriorityCallback(mod, id, 0, fn, param) end
function Isaac.RemoveCallback(mod, id, fn)
	local list = H.callbacks[id] or {}
	for i = #list, 1, -1 do
		if list[i].Function == fn then table.remove(list, i) end
	end
end
function Isaac.GetCallbacks(id) return H.callbacks[id] or {} end
function Isaac.SaveModData(mod, data) H.modData = data end
function Isaac.LoadModData() return H.modData end
function Isaac.HasModData() return H.modData ~= nil end
function Isaac.GetScreenWidth() return 480 end
function Isaac.GetScreenHeight() return 270 end
function Isaac.GetPlayer(i) return H.players[(i or 0) + 1] end
function Isaac.GetRoomEntities() return H.entities end
function Isaac.DebugString(s) H.log[#H.log + 1] = s end
function Isaac.ConsoleOutput(s) H.log[#H.log + 1] = s end
function Isaac.GetFrameCount() return H.frame end
function Isaac.GetItemIdByName() return -1 end -- Completion Marks calls these two at load and on render
function Isaac.GetChallenge() return 0 end

function RegisterMod(name, apiVersion)
	local mod = { Name = name }
	function mod:AddCallback(id, fn, param) Isaac.AddCallback(self, id, fn, param) end
	function mod:AddPriorityCallback(id, priority, fn, param) Isaac.AddPriorityCallback(self, id, priority, fn, param) end
	function mod:RemoveCallback(id, fn) Isaac.RemoveCallback(self, id, fn) end
	function mod:SaveData(data) Isaac.SaveModData(self, data) end
	function mod:LoadData() return Isaac.LoadModData(self) end
	function mod:HasData() return Isaac.HasModData(self) end
	Isaac.RegisterMod(mod, name, apiVersion)
	return mod
end

-- Runs a callback id like the engine's _RunCallback: first non-nil return wins.
function H.fire(id, ...)
	for _, entry in ipairs(H.callbacks[id] or {}) do
		local result = entry.Function(entry.Mod, ...)
		if result ~= nil then return result end
	end
end

-- One render frame with the given input; input is cleared afterwards.
function H.render() H.fire(ModCallbacks.MC_POST_RENDER) H.clearInput() end
function H.update() H.frame = H.frame + 1 H.fire(ModCallbacks.MC_POST_UPDATE) end

function H.loadMod()
	dofile(ROOT .. "main.lua")
	return require("scripts.modconfig")
end
