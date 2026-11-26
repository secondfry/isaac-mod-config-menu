-- The API entry: main.lua and dependents require("scripts.modconfig") and all get this one table.
local VERSION = 205 -- the original reports 204; a copy already loaded with the same or a higher Version is used instead

local existing = (type(MCM) == "table" and MCM) or (type(ModConfigMenu) == "table" and ModConfigMenu) or nil
if existing and (tonumber(existing.Version) or 0) >= VERSION then return existing end

local util = include("scripts.util")
local mod = RegisterMod(util.NAME, 1)
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
function api.GetVersionString() return "1.1" end

include("scripts.registry")(api, util)
local keys = include("scripts.keys")(api, util)
include("scripts.screen")(api, util)
include("scripts.config")(api, util)
include("scripts.settings")(api, keys)
local input = include("scripts.input")(api, util)
local nav = include("scripts.navigation")(api, util, keys)
local render = include("scripts.render")(api, util, nav)
local menu = include("scripts.menu")(api, util, mod, input, nav, render)
include("scripts.builtin")(api, util, menu)
include("scripts.filepath")(api)
include("scripts.compat")(api, util, menu)
-- An older copy loaded first keeps running beside this one; the player is told to keep only one.
if existing then menu.noticeOtherCopy() end
menu.load()
MCM, ModConfigMenu, ScreenHelper, InputHelper, FilepathHelper, ModConfigMenuData = api, api, api, api, api, api.MenuData
return api
