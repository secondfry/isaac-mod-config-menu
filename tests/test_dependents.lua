-- Real dependents' menu code, loaded against the stub with this mod loaded first.
local T = {}
local function test(name, fn) T[#T + 1] = { name, fn } end
local H = Harness

local function anyConfig()
	return setmetatable({}, { __index = function() return 1 end })
end

local function rowCount(api, cat)
	local category = api.MenuData[api.GetCategoryIDByName(cat)]
	local n = 0
	for _, sub in ipairs(category.Subcategories) do n = n + #sub.Options end
	return n
end

-- Walks every row of every subcategory of cat, rendering each frame, so each Display runs.
local function browse(api, cat)
	local id = api.GetCategoryIDByName(cat)
	local function tap(a)
		H.pressAction(a, -2)
		H.render()
		H.render()
	end
	H.pressButton(Keyboard.KEY_L, -2)
	H.render()
	for _ = 2, id do tap(ButtonAction.ACTION_DOWN) end
	tap(ButtonAction.ACTION_RIGHT)
	for _, sub in ipairs(api.MenuData[id].Subcategories) do
		tap(ButtonAction.ACTION_DOWN)
		for _ = 1, #sub.Options do tap(ButtonAction.ACTION_DOWN) end
		tap(ButtonAction.ACTION_MENUBACK)
		tap(ButtonAction.ACTION_RIGHT)
	end
end

test("EID features/eid_mcm.lua registers its pages", function()
	local api = H.loadMod()
	EID = {
		ModIndicator = {}, Config = anyConfig(), DefaultConfig = {}, isRepentance = true,
		Languages = { "en_us" }, descriptions = { en_us = { languageName = "English", fonts = { { name = "default" } } } },
		InlineColors = {}, ModVersion = 4.0, ModVersionCommit = "x", GameVersion = "rep+", BoC = {},
	}
	dofile(GAME_MODS .. "external item descriptions_836319872/features/eid_mcm.lua")
	ok(EID.MCMLoaded, "EID found the menu through require")
	ok(rowCount(api, "EID") > 100, "EID rows registered")
	ok(api.GetSubcategoryIDByName("EID", "General") ~= nil, "General tab")
	EID:renderMCMDummyDescription()
end)

test("MinimapAPI config_menu.lua registers and every row renders", function()
	local api = H.loadMod()
	MinimapAPI = { Config = anyConfig() }
	package.preload["scripts.minimapapi"] = function() return MinimapAPI end
	package.preload["scripts.minimapapi.config_presets"] = function() return {} end
	dofile(GAME_MODS .. "minimapi_1978904635/scripts/minimapapi/config_menu.lua")
	ok(rowCount(api, "Minimap API") > 40, "MinimapAPI rows registered")
	browse(api, "Minimap API")
end)

test("Completion Marks main.lua registers through ModConfigMenu at load", function()
	local api = H.loadMod()
	dofile(GAME_MODS .. "completionmarksrep_2503022727/main.lua")
	ok(api.GetSubcategoryIDByName("Completion Marks", "General   ") ~= nil, "trailing-space tab")
	eq(rowCount(api, "Completion Marks"), 18, "its rows")
	H.addPlayer()
	browse(api, "Completion Marks")
end)

return T
