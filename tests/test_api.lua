-- API surface: globals, the data model, helper settings and saving.
local T = {}
local function test(name, fn) T[#T + 1] = { name, fn } end
local H = Harness

local function rows(api, cat, sub)
	local c = api.MenuData[api.GetCategoryIDByName(cat)]
	return c.Subcategories[api.GetSubcategoryIDByName(cat, sub or "Uncategorized")].Options
end

test("require returns the one table every global names", function()
	local api = H.loadMod()
	eq(require("scripts.modconfig"), api, "second require")
	for _, name in ipairs({ "MCM", "ModConfigMenu", "ScreenHelper", "InputHelper", "FilepathHelper" }) do
		eq(_G[name], api, name)
	end
	eq(ModConfigMenuData, api.MenuData, "ModConfigMenuData")
	eq(api.Version, 205, "Version")
	ok(FilepathHelper.Version >= 4, "FilepathHelper.Version keeps Encyclopedia's copy dormant")
	eq(api.RegisterMod, Isaac.RegisterMod, "RegisterMod")
	eq(api.IsAnm2("x"), false, "IsAnm2")
	ok(rawget(api, "i18n") == nil and api.i18n ~= "Chinese", "i18n unset, so EID's Chinese-only calls stay skipped")
	eq(ModConfigMenuOptionType.BOOLEAN, 4, "deprecated OptionType forwards")
	eq(Controller.STICK_RIGHT, 13, "Controller enum")
end)

test("FilepathHelper.RegisterMod gives every later mod a string path", function()
	local api = H.loadMod()
	eq(Isaac.RegisterMod, api.RegisterMod, "Isaac.RegisterMod replaced")
	ok(api.OldRegisterMod ~= api.RegisterMod, "OldRegisterMod is the engine's")
	package.path = "C:/game/resources/scripts/?.lua;C:/game/mods/foo_1/?.lua"
	-- Encyclopedia wraps Isaac.RegisterMod after us and concatenates ref.path for each new mod.
	local engineLater = Isaac.RegisterMod
	local seen
	Isaac.RegisterMod = function(ref, name, v)
		engineLater(ref, name, v)
		seen = ref.path .. "content/gfx/ui_cardfronts.anm2"
	end
	local mod = RegisterMod("Later", 1)
	eq(mod.path, "C:/game/mods/foo_1/", "root of the loading mod")
	eq(seen, "C:/game/mods/foo_1/content/gfx/ui_cardfronts.anm2", "concatenation works")
	eq(api.GetCurrentModPath(), "C:/game/mods/foo_1/", "GetCurrentModPath")
	ok(api.KnownFilePathsByName["C:/game/mods/foo_1/"], "path recorded")
	package.path = "C:/game/resources/scripts/?.lua;C:/game/mods/shotty's pack_2/?.lua"
	eq(RegisterMod("Apostrophe", 1).path, "C:/game/mods/shotty's pack_2/", "a folder name with an apostrophe")
	package.path = "C:/game/mods/x_3/?.lua;C:/b/?.luac;C:/game/mods/y_4/?.lua"
	local spanned = RegisterMod("NotLua", 1).path
	ok(not spanned:find("\n"), "an entry without .lua' on its line does not join lines into the path")
	package.path, package.cpath = "C:/only/?.lua", ""
	eq(RegisterMod("NoRoot", 1).path, "", "no derivable root: empty string")
	api.OldRegisterMod = function() error("boom") end
	raises(function() api.RegisterMod({}, "Bad", 1) end, "boom", "engine error rethrown")
end)

test("a same or newer copy already loaded is returned unchanged", function()
	local newer = { Version = 300, MenuData = {} }
	MCM = newer
	eq(H.loadMod(), newer, "newer copy")
end)

test("keybind helpers blame the calling file for a missing attribute", function()
	local api = H.loadMod()
	raises(function() api.AddKeyboardSetting("Cat") end, "test_api%.lua", "AddKeyboardSetting")
	raises(function() api.AddControllerSetting("Cat") end, "test_api%.lua", "AddControllerSetting")
end)

test("AddSetting shifts with two args and defaults to Uncategorized", function()
	local api = H.loadMod()
	local a = api.AddSetting("Cat", { Type = 4, Display = "a" })
	local b = api.AddSetting("Cat", nil, { Type = 4, Display = "b" })
	local c = api.AddSetting("Cat", "Tab", { Type = 4, Display = "c" })
	local uncategorized = rows(api, "Cat")
	eq(uncategorized[1], a, "two-arg row")
	eq(uncategorized[2], b, "explicit nil sub")
	eq(rows(api, "Cat", "Tab")[1], c, "named sub")
	raises(function() api.AddSetting(nil, {}) end, "AddSetting", "nil category")
end)

test("AddText and AddTitle shift only without a colour and with a non-text third arg", function()
	local api = H.loadMod()
	local t1 = api.AddText("Cat", "hello")
	eq(t1.Display, "hello", "text without sub")
	eq(t1.NoCursorHere, true, "NoCursorHere")
	local t2 = api.AddText("Cat", "Tab", "hi")
	eq(rows(api, "Cat", "Tab")[1], t2, "text with sub")
	local fn = function() return "f" end
	local t3 = api.AddText("Cat", "Tab", fn)
	eq(t3.Display, fn, "function text")
	local color = { 1, 0, 0 }
	local t4 = api.AddTitle("Cat", "Title", color)
	eq(t4.Type, api.OptionType.TITLE, "title type")
	eq(t4.Display, "Title", "title text shifted")
	eq(t4.Color, color, "title colour shifted")
	eq(rows(api, "Cat")[2], t4, "title in Uncategorized")
	local space = api.AddSpace("Cat", "Tab")
	eq(space.Type, api.OptionType.SPACE, "space")
	eq(api.AddSpace("Cat").Type, 2, "space without sub")
end)

test("category and subcategory lookup, update and removal", function()
	local api = H.loadMod()
	api.UpdateCategory("Stats+", { Info = "info", IsOld = false })
	local id = api.GetCategoryIDByName("Stats+")
	eq(api.MenuData[id].Info, "info", "Info copied")
	eq(api.MenuData[id].IsOld, nil, "IsOld=false is not copied")
	api.UpdateCategory("Stats+", { Name = "Renamed", IsOld = true })
	eq(api.MenuData[id].Name, "Renamed", "data.Name wins")
	eq(api.MenuData[id].IsOld, true, "IsOld true copied")
	eq(api.GetCategoryIDByName("General   "), nil, "names match exactly")
	eq(api.GetCategoryIDByName(99), nil, "missing index")
	eq(api.GetSubcategoryIDByName("Missing", "x"), nil, "missing category")
	raises(function() api.UpdateCategory(nil) end, "UpdateCategory", "bad name")
	api.UpdateSubcategory("Renamed", "Tab", { Info = "tab info" })
	eq(api.MenuData[id].Subcategories[1].Info, "tab info", "subcategory info")
	eq(api.RemoveSubcategory("Renamed", "Tab"), true, "RemoveSubcategory")
	eq(api.RemoveSubcategory("Renamed", "Tab"), false, "RemoveSubcategory again")
	eq(api.RemoveCategory("Renamed"), true, "RemoveCategory")
	eq(api.RemoveCategory("Renamed"), false, "RemoveCategory again")
end)

test("RemoveSetting removes the last Attribute match, else the last Display match", function()
	local api = H.loadMod()
	api.AddSetting("Cat", { Type = 4, Attribute = "k", Display = "first" })
	api.AddSetting("Cat", { Type = 4, Attribute = "k", Display = "second" })
	api.AddSetting("Cat", { Type = 4, Display = "k" })
	eq(api.RemoveSetting("Cat", "k"), true, "by attribute")
	local r = rows(api, "Cat")
	eq(#r, 2, "one removed")
	eq(r[1].Display, "first", "last attribute match went")
	eq(api.RemoveSetting("Cat", "k"), true, "second by attribute")
	eq(api.RemoveSetting("Cat", nil, "k"), true, "then by display")
	eq(#r, 0, "all gone")
	eq(api.RemoveSetting("Cat", "k"), false, "nothing left")
end)

test("AddBooleanSetting shifts a non-boolean default into the display text", function()
	local api = H.loadMod()
	local s = api.AddBooleanSetting("Completion Marks", "General   ", "completionmode", 74, "Change where the Marks Appear")
	eq(s.Default, false, "default false")
	eq(api.Config["Completion Marks"].completionmode, false, "stored in Config")
	eq(s.Info, "Change where the Marks Appear", "string info after skipped proxies")
	eq(s.Display(), "74: false", "display text is the shifted 74")
	eq(rows(api, "Completion Marks", "General   ")[1], s, "trailing-space subcategory")
	local p = api.AddBooleanSetting("Cat", "flag", true, "Flag", { [true] = "ON", [false] = "OFF" }, "info")
	eq(p.Display(), "Flag: ON", "value proxy")
	eq(p.Info, "info", "info")
	local q = api.AddBooleanSetting("Cat", "flag2", true, "Flag", { "line" })
	eq(type(q.Info), "table", "a table with nil info after it is the info")
	raises(function() api.AddBooleanSetting(nil, "x") end, "AddBooleanSetting", "nil category")
end)

test("AddNumberSetting treats a string default as a missing modifyBy", function()
	local api = H.loadMod()
	local s = api.AddNumberSetting("Cat", "n", 0, 5, 2, "Number")
	eq(s.ModifyBy, 1, "modifyBy defaulted")
	eq(s.Default, 2, "default")
	eq(s.Display(), "Number: 2", "display")
	local t = api.AddNumberSetting("Cat", "Tab", "m", 1, 9, 2, 3, "M")
	eq(t.ModifyBy, 2, "explicit modifyBy")
	eq(t.Default, 3, "explicit default")
	eq(api.Config.Cat.m, 3, "stored")
end)

test("AddScrollSetting and keybind helpers shift and alternate sliders", function()
	local api = H.loadMod()
	local s1 = api.AddScrollSetting("Cat", "Tab", "s", "Scroll")
	local s2 = api.AddScrollSetting("Cat", "s2", 4, "Scroll")
	eq(s1.Attribute, "s", "a string third arg means the subcategory was given")
	eq(s1.Default, 0, "scroll default")
	eq(s1.Display(), "Scroll: $scroll0", "scroll display")
	eq(s2.Display(), "Scroll: $scroll4", "scroll value")
	ok(s1.AltSlider ~= s2.AltSlider, "AltSlider alternates")
	local k = api.AddKeyboardSetting("Cat", "key", -1, "Key", "info")
	eq(k.Default, -1, "keybind default")
	eq(k.Info, "info", "non-boolean device shifted")
	eq(k.Display(), "Key: None", "unbound display")
	eq(k.PopupGfx, api.PopupGfx.WIDE_SMALL, "popup gfx")
	eq(k.PopupWidth, 280, "popup width")
	local c = api.AddControllerSetting("Cat", "button", 13, "Btn", true)
	eq(c.Display(), "Btn: RIGHT STICK (controller)", "controller display")
	ok(c.Popup():find("controller"), "popup text names the device")
	c.OnChange(nil)
	eq(api.Config.Cat.button, -1, "helper unbind stores -1")
end)

test("key names follow the enum rules", function()
	local api = H.loadMod()
	eq(api.KeyboardToString[Keyboard.KEY_LEFT_SHIFT], "LEFT SHIFT", "keyboard")
	eq(api.KeyboardToString[Keyboard.KEY_ESCAPE], "ESCAPE", "escape")
	local want = { [0] = "DPAD LEFT", [4] = "A", [8] = "LEFT BUMPER", [12] = "RIGHT TRIGGER", [10] = "LEFT STICK", [14] = "BACK", [15] = "START" }
	for code, name in pairs(want) do eq(api.ControllerToString[code], name, "button " .. code) end
	local count = 0
	for _ in pairs(api.ControllerToString) do count = count + 1 end
	eq(count, 16, "all 16 buttons")
end)

test("save and load: defaults, then saved, then current for keys neither has", function()
	local api = H.loadMod()
	api.AddBooleanSetting("Cat", "a", true, "A")
	api.AddBooleanSetting("Cat", "b", true, "B")
	api.Config.Cat.a, api.Config.Cat.b = false, false
	api.Config.Extra = { onlyCurrent = 1 }
	local saved = '{"Cat":{"a":false},"Unknown":{"z":5}}'
	local result = api.LoadSave(saved)
	eq(result, api.Config, "returns the new Config")
	eq(api.Config.Cat.a, false, "saved wins")
	eq(api.Config.Cat.b, true, "default wins over current")
	eq(api.Config.Unknown.z, 5, "saved-only key kept")
	eq(api.Config.Extra.onlyCurrent, 1, "current kept where neither has the key")
	eq(api.LoadSave("not json"), nil, "bad JSON")
	eq(api.LoadSave(nil), nil, "nil input")
	eq(api.Config.General.HudOffset, 7, "General mirrors Options")
	eq(api.Config.HudOffset, 7, "legacy top-level key redirects")
	local decoded = require("json").decode(api.GetSave())
	eq(decoded.Cat.a, false, "GetSave is JSON of Config")
end)

test("saved values are in Config before dependents register", function()
	H.modData = '{"Late":{"x":true},"Mod Config Menu":{"OpenMenuKeyboard":75}}'
	local api = H.loadMod()
	local s = api.AddBooleanSetting("Late", "x", false, "X")
	eq(s.CurrentSetting(), true, "saved value survives the helper's default")
	eq(api.Config["Mod Config Menu"].OpenMenuKeyboard, 75, "own setting loaded")
end)

test("screen helpers and HUD offset", function()
	local api = H.loadMod()
	eq(api.GetOffset(), 7, "offset from Options")
	api.SetOffset(12)
	eq(api.GetOffset(), 10, "clamped")
	eq(Options.HUDOffset, 1, "written back")
	local tl = api.GetScreenTopLeft(5)
	eq(tl.X, 10, "top left moves inward")
	eq(api.GetScreenBottomRight(0).X, 480, "no offset")
	eq(api.GetScreenCenter().Y, 135, "centre")
end)

return T
