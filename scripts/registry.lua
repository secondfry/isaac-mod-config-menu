-- Menu data model: categories, their subcategories and the rows dependents add to them.
local UNCATEGORIZED = "Uncategorized"
local GFX = "gfx/configmenu/"

return function(api)
	api.OptionType = {
		TEXT = 1, SPACE = 2, SCROLL = 3, BOOLEAN = 4, NUMBER = 5,
		KEYBIND_KEYBOARD = 6, KEYBIND_CONTROLLER = 7, TITLE = 8,
	}
	api.PopupGfx = {
		THIN_SMALL = GFX .. "popup_thin_small.png",
		THIN_MEDIUM = GFX .. "popup_thin_medium.png",
		THIN_LARGE = GFX .. "popup_thin_large.png",
		WIDE_SMALL = GFX .. "popup_wide_small.png",
		WIDE_MEDIUM = GFX .. "popup_wide_medium.png",
		WIDE_LARGE = GFX .. "popup_wide_large.png",
	}
	api.MenuData = {}

	-- Error level 3 blames the dependent that called the public function.
	local function checkKey(fnName, argName, key)
		local kind = type(key)
		if kind == "string" or kind == "number" then return end
		error(string.format("%s: bad argument '%s' (name or index expected, got %s)", fnName, argName, kind), 3)
	end

	-- A string matches Name exactly; anything else is the index itself.
	local function findIndex(list, key)
		if type(key) ~= "string" then return list[key] ~= nil and key or nil end
		for i, entry in ipairs(list) do
			if entry.Name == key then return i end
		end
	end

	local function ensure(list, key, make)
		local i = findIndex(list, key)
		if i then return list[i] end
		local named = type(key) == "string"
		local entry = make(named and key or nil)
		if named then list[#list + 1] = entry else list[key] = entry end
		return entry
	end

	local function ensureCategory(key)
		return ensure(api.MenuData, key, function(name) return { Name = name, Subcategories = {} } end)
	end

	local function ensureSubcategory(catKey, subKey)
		local category = ensureCategory(catKey)
		category.Subcategories = category.Subcategories or {}
		local sub = ensure(category.Subcategories, subKey, function(name) return { Name = name, Options = {} } end)
		sub.Options = sub.Options or {}
		return sub
	end

	local function subcategoriesOf(catKey)
		local i = findIndex(api.MenuData, catKey)
		return i and (api.MenuData[i].Subcategories or {}) or nil
	end

	local function removeAt(list, i)
		if not i then return false end
		if i <= #list then table.remove(list, i) else list[i] = nil end
		return true
	end

	function api.GetCategoryIDByName(name)
		return findIndex(api.MenuData, name)
	end

	function api.UpdateCategory(name, data)
		checkKey("UpdateCategory", "name", name)
		data = data or {}
		local category = ensureCategory(name)
		if data.Name ~= nil then
			category.Name = data.Name
		elseif type(name) == "string" then
			category.Name = name
		end
		if data.Info then category.Info = data.Info end
		if data.IsOld then category.IsOld = data.IsOld end
	end

	function api.SetCategoryInfo(name, info)
		checkKey("SetCategoryInfo", "name", name)
		api.UpdateCategory(name, { Info = info })
	end

	function api.RemoveCategory(name)
		return removeAt(api.MenuData, findIndex(api.MenuData, name))
	end

	function api.GetSubcategoryIDByName(cat, sub)
		local subs = subcategoriesOf(cat)
		return subs and findIndex(subs, sub)
	end

	function api.UpdateSubcategory(cat, sub, data)
		checkKey("UpdateSubcategory", "category", cat)
		checkKey("UpdateSubcategory", "subcategory", sub)
		data = data or {}
		local subcategory = ensureSubcategory(cat, sub)
		if data.Name ~= nil then
			subcategory.Name = data.Name
		elseif type(sub) == "string" then
			subcategory.Name = sub
		end
		if data.Info ~= nil then subcategory.Info = data.Info end
	end

	function api.RemoveSubcategory(cat, sub)
		local subs = subcategoriesOf(cat)
		return subs ~= nil and removeAt(subs, findIndex(subs, sub))
	end

	function api.AddSetting(cat, sub, setting)
		if setting == nil then sub, setting = nil, sub end
		sub = sub == nil and UNCATEGORIZED or sub
		checkKey("AddSetting", "category", cat)
		checkKey("AddSetting", "subcategory", sub)
		local options = ensureSubcategory(cat, sub).Options
		options[#options + 1] = setting
		return setting
	end

	local function addLabel(optionType, cat, sub, text, color)
		if color == nil and type(text) ~= "string" and type(text) ~= "function" then
			sub, text, color = nil, sub, text
		end
		return api.AddSetting(cat, sub, { Type = optionType, Display = text, Color = color, NoCursorHere = true })
	end

	function api.AddText(cat, sub, text, color)
		checkKey("AddText", "category", cat)
		return addLabel(api.OptionType.TEXT, cat, sub, text, color)
	end

	function api.AddTitle(cat, sub, text, color)
		checkKey("AddTitle", "category", cat)
		return addLabel(api.OptionType.TITLE, cat, sub, text, color)
	end

	function api.AddSpace(cat, sub)
		checkKey("AddSpace", "category", cat)
		return api.AddSetting(cat, sub, { Type = api.OptionType.SPACE })
	end

	-- Removes the last row whose Attribute is key, else the last whose Display is key.
	function api.RemoveSetting(cat, sub, key)
		if key == nil then sub, key = nil, sub end
		if key == nil then return false end
		local subs = subcategoriesOf(cat) or {}
		local i = findIndex(subs, sub == nil and UNCATEGORIZED or sub)
		local options = i and subs[i].Options or {}
		for _, field in ipairs({ "Attribute", "Display" }) do
			for row = #options, 1, -1 do
				if options[row][field] == key then
					table.remove(options, row)
					return true
				end
			end
		end
		return false
	end
end
