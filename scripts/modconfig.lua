-- The API entry: main.lua and dependents require("scripts.modconfig") and all get this one table.
local VERSION = 205 -- above the original's 204, so an embedded older copy hands over to this one

local existing = (type(MCM) == "table" and MCM) or (type(ModConfigMenu) == "table" and ModConfigMenu) or nil
if existing and (tonumber(existing.Version) or 0) >= VERSION then return existing end

local util = include("scripts.util")
local mod = RegisterMod("Config Menu", 1)
local api = {
	Version = VERSION,
	DLC = REPENTANCE_PLUS and 4 or 3,
	WarningOffset = 28,
	WarningOffsetDSS = 50,
	CompatibilityMode = true,
	Mod = mod,
	StandaloneMod = mod,
	Round = util.Round,
	RoundVector = util.RoundVector,
	CopyTable = util.CopyTable,
	FillTable = util.FillTable,
	ConvertDisplayToTextTable = util.ConvertDisplayToTextTable,
}
function api.GetVersionString() return "1.0" end

include("scripts.registry")(api)
local keys = include("scripts.keys")(api, util)
include("scripts.config")(api, util)
include("scripts.settings")(api, keys)
include("scripts.screen")(api, util)
local input = include("scripts.input")(api)
local nav = include("scripts.navigation")(api, util, keys)
local render = include("scripts.render")(api, util, nav)
local menu = include("scripts.menu")(api, mod, input, nav, render)
include("scripts.builtin")(api, menu.applyHud)

-- An older copy hands over the pages other mods gave it; its own two pages and callbacks go.
local OLD_OWN_PAGES = { General = true, ["Mod Config Menu"] = true, ["Config Menu"] = true }
local function takeOver(old)
	for _, category in ipairs(old.MenuData or {}) do
		if not OLD_OWN_PAGES[category.Name] then api.MenuData[#api.MenuData + 1] = category end
	end
	-- shortcut: their helper rows still read the old Config table, so those values stop saving; copy the closures over if an embedded older copy ever appears.
	util.FillTable(api.Config, old.Config or {})
	local oldMods = { [old.Mod or false] = true, [old.StandaloneMod or false] = true }
	for _, id in pairs(ModCallbacks) do
		local callbacks = Isaac.GetCallbacks(id)
		for i = #callbacks, 1, -1 do
			local entry = callbacks[i]
			if entry and oldMods[entry.Mod] then Isaac.RemoveCallback(entry.Mod, id, entry.Function) end
		end
	end
end
if existing then takeOver(existing) end

include("scripts.compat")(api)
menu.load()
MCM, ModConfigMenu = api, api
return api
