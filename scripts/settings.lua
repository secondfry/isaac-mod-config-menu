-- Helper settings: rows whose value the menu keeps in Config[category][attribute] and saves.
return function(api, keys)
	local T = api.OptionType
	local nextAltSlider = false

	-- An optional argument that fails its test is absent: it becomes nil and the later ones move one place on.
	local function shiftAt(args, i)
		for k = args.n, i, -1 do args[k + 1] = args[k] end
		args[i] = nil
		args.n = math.max(args.n, i - 1) + 1
	end

	local function shiftSubcategory(args)
		if type(args[3]) ~= "string" then shiftAt(args, 2) end
	end

	local function shiftProxies(args, i)
		local info = args[i + 1]
		if type(args[i]) ~= "table" or info == nil or type(info) == "userdata" then shiftAt(args, i) end
	end

	local function requireKeys(fnName, args, level)
		if args[1] ~= nil and args[3] ~= nil then return end
		error(fnName .. ": category and attribute are required", level)
	end

	local function valueOf(cat, attr)
		local section = api.Config[cat]
		return section and section[attr]
	end

	local function store(cat, attr, value)
		api.Config[cat] = api.Config[cat] or {}
		api.Config[cat][attr] = value
	end

	local function register(cat, sub, attr, default, setting)
		api.ConfigDefault[cat] = api.ConfigDefault[cat] or {}
		api.ConfigDefault[cat][attr] = default
		if valueOf(cat, attr) == nil then store(cat, attr, default) end
		setting.Attribute = attr
		setting.Default = default
		setting.CurrentSetting = function() return valueOf(cat, attr) end
		setting.OnChange = function(value) store(cat, attr, value) end
		return api.AddSetting(cat, sub, setting)
	end

	local function label(displayText, value)
		return tostring(displayText) .. ": " .. tostring(value)
	end

	local function proxied(proxies, value)
		return proxies and proxies[value] or value
	end

	function api.AddBooleanSetting(...)
		local a = table.pack(...)
		shiftSubcategory(a)
		if type(a[4]) ~= "boolean" then shiftAt(a, 4) end
		shiftProxies(a, 6)
		requireKeys("AddBooleanSetting", a, 3)
		local cat, attr, text, proxies = a[1], a[3], a[5], a[6]
		return register(cat, a[2], attr, a[4] or false, {
			Type = T.BOOLEAN, Info = a[7], Color = a[8],
			Display = function() return label(text, proxied(proxies, valueOf(cat, attr))) end,
		})
	end

	function api.AddNumberSetting(...)
		local a = table.pack(...)
		shiftSubcategory(a)
		if type(a[7]) == "string" then shiftAt(a, 6) end
		shiftProxies(a, 9)
		requireKeys("AddNumberSetting", a, 3)
		local cat, attr, text, proxies = a[1], a[3], a[8], a[9]
		return register(cat, a[2], attr, a[7] or 0, {
			Type = T.NUMBER, Minimum = a[4] or 0, Maximum = a[5] or 10, ModifyBy = a[6] or 1,
			Info = a[10], Color = a[11],
			Display = function() return label(text, proxied(proxies, valueOf(cat, attr))) end,
		})
	end

	function api.AddScrollSetting(...)
		local a = table.pack(...)
		shiftSubcategory(a)
		if type(a[4]) ~= "number" then shiftAt(a, 4) end
		requireKeys("AddScrollSetting", a, 3)
		local cat, attr, text = a[1], a[3], a[5]
		local setting = register(cat, a[2], attr, a[4] or 0, {
			Type = T.SCROLL, Info = a[6], Color = a[7], AltSlider = nextAltSlider,
			Display = function() return label(text, "$scroll" .. math.floor(valueOf(cat, attr) or 0)) end,
		})
		nextAltSlider = not nextAltSlider
		return setting
	end

	local function addKeybind(fnName, optionType, ...)
		local a = table.pack(...)
		shiftSubcategory(a)
		if type(a[4]) ~= "number" then shiftAt(a, 4) end
		if type(a[6]) ~= "boolean" then shiftAt(a, 6) end
		requireKeys(fnName, a, 3)
		local cat, attr, text, showDevice = a[1], a[3], a[5], a[6]
		local setting = register(cat, a[2], attr, a[4] or -1, {
			Type = optionType, Info = a[7], Color = a[8],
			PopupGfx = api.PopupGfx.WIDE_SMALL, PopupWidth = 280,
			Display = function()
				local shown = label(text, keys.keyName(optionType, valueOf(cat, attr)))
				return showDevice and shown .. " (" .. keys.deviceName(optionType) .. ")" or shown
			end,
		})
		setting.Popup = function() return keys.bindPopupText(setting) end
		setting.OnChange = function(value) store(cat, attr, value == nil and -1 or value) end
		return setting
	end

	-- Tail calls: the caller's frame is replaced, so level 3 in requireKeys blames the dependent.
	function api.AddKeyboardSetting(...)
		return addKeybind("AddKeyboardSetting", T.KEYBIND_KEYBOARD, ...)
	end

	function api.AddControllerSetting(...)
		return addKeybind("AddControllerSetting", T.KEYBIND_CONTROLLER, ...)
	end
end
