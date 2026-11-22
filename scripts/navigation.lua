-- Cursor and focus over MenuData, and what each menu input does to the highlighted row.
local CATEGORIES, TABS, OPTIONS = "categories", "tabs", "options"
local LAST_KNOWN_TYPE = 8
local RESTART_POPUP = "This change takes effect after you restart the game."
local RERUN_POPUP = "This change takes effect from your next run."

return function(api, util, keys)
	local T = api.OptionType
	local EDITABLE = {
		[T.BOOLEAN] = true, [T.NUMBER] = true, [T.SCROLL] = true,
		[T.KEYBIND_KEYBOARD] = true, [T.KEYBIND_CONTROLLER] = true,
	}
	local nav = {
		CATEGORIES = CATEGORIES, TABS = TABS, OPTIONS = OPTIONS,
		focus = CATEGORIES, cat = 1, sub = 1, opt = 1, popup = nil,
		restartWarning = false, rerunWarning = false,
	}

	function nav.category() return api.MenuData[nav.cat] end

	function nav.subcategories()
		local category = nav.category()
		return category and category.Subcategories or {}
	end

	-- A category holding only "Uncategorized" opens straight into its rows.
	function nav.hasTabBar()
		local subs = nav.subcategories()
		return #subs > 1 or (#subs == 1 and subs[1].Name ~= "Uncategorized")
	end

	function nav.options()
		local sub = nav.subcategories()[nav.sub]
		return sub and sub.Options or {}
	end

	function nav.option() return nav.options()[nav.opt] end

	function nav.isKnown(opt)
		return type(opt.Type) == "number" and opt.Type >= 1 and opt.Type <= LAST_KNOWN_TYPE
	end

	function nav.isSelectable(opt)
		return opt ~= nil and nav.isKnown(opt) and opt.Type ~= T.SPACE and opt.Display ~= nil
			and not util.Resolve(opt.NoCursorHere)
	end

	local function wrap(i, n) return (i - 1) % n + 1 end

	local function findSelectable(from, dir)
		local options = nav.options()
		for step = 0, #options - 1 do
			local i = wrap(from + step * dir, #options)
			if nav.isSelectable(options[i]) then return i end
		end
	end

	function nav.reset()
		nav.focus, nav.cat, nav.sub, nav.opt, nav.popup = CATEGORIES, 1, 1, 1, nil
	end

	local function play(sound, volume) SFXManager():Play(sound, volume or 1) end

	function nav.buzz() play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.75) end

	-- Dependents may remove categories or rows while the menu is open.
	local function clampCursor()
		local count = #api.MenuData
		if count == 0 then return nav.reset() end
		if nav.cat > count then nav.cat, nav.sub, nav.opt, nav.focus = count, 1, 1, CATEGORIES end
		if nav.sub > math.max(#nav.subcategories(), 1) then nav.sub, nav.opt = 1, 1 end
		if nav.focus == TABS and not nav.hasTabBar() then nav.focus = CATEGORIES end
		if nav.focus == OPTIONS and not nav.isSelectable(nav.option()) then
			local i = findSelectable(nav.opt, 1)
			if i then nav.opt = i else nav.focus = nav.hasTabBar() and TABS or CATEGORIES end
		end
	end

	local function valueOf(opt) return util.Resolve(opt.CurrentSetting) end

	local function change(opt, value)
		if type(opt.CurrentSetting) == "function" then
			if opt.OnChange then opt.OnChange(value) end
		else
			opt.CurrentSetting = value
		end
		local sound = opt.Sound or SoundEffect.SOUND_PLOP
		if sound >= 0 then play(sound) end
		if opt.Popup then return end
		if opt.Rerun then nav.rerunWarning, nav.popup = true, { kind = "warning", option = opt, text = RERUN_POPUP } end
		if opt.Restart then nav.restartWarning, nav.popup = true, { kind = "warning", option = opt, text = RESTART_POPUP } end
	end

	local function stepNumber(opt, dir)
		local scroll = opt.Type == T.SCROLL
		local min, max = opt.Minimum, opt.Maximum
		local by = opt.ModifyBy or 1
		if scroll then min, max, by = 0, 10, 1 end
		local value = (tonumber(valueOf(opt)) or min or 0) + by * dir
		value = by % 1 == 0 and math.floor(value) or util.Round(value, 3)
		local clamp = scroll or opt.NoLoopFromMaxMin
		if max and value > max then value = clamp and max or (min or max) end
		if min and value < min then value = clamp and min or (max or min) end
		change(opt, value)
	end

	local function enterOptions()
		local i = findSelectable(1, 1)
		if i then nav.opt, nav.focus = i, OPTIONS end
	end

	local function leaveOptions()
		nav.focus = nav.hasTabBar() and TABS or CATEGORIES
	end

	local function categoriesInput(frame)
		if frame.back then return "close" end
		local count = #api.MenuData
		if frame.up or frame.down then
			nav.cat, nav.sub, nav.opt = wrap(nav.cat + (frame.down and 1 or -1), count), 1, 1
		elseif frame.right or frame.select then
			if nav.hasTabBar() then nav.focus = TABS else enterOptions() end
		end
	end

	local function tabsInput(frame)
		local count = #nav.subcategories()
		if frame.back or frame.up then
			nav.focus = CATEGORIES
		elseif frame.left or frame.right then
			nav.sub, nav.opt = wrap(nav.sub + (frame.right and 1 or -1), count), 1
		elseif frame.down or frame.select then
			enterOptions()
		end
	end

	local function optionsInput(frame)
		local opt = nav.option()
		local kind = opt.Type
		if frame.back then return leaveOptions() end
		if frame.up or frame.down then
			local dir = frame.down and 1 or -1
			nav.opt = findSelectable(nav.opt + dir, dir) or nav.opt
		elseif frame.reset and EDITABLE[kind] and opt.Default ~= nil then
			change(opt, util.Resolve(opt.Default))
		elseif kind == T.BOOLEAN then
			if frame.left or frame.right or frame.select then change(opt, not valueOf(opt)) end
		elseif kind == T.NUMBER or kind == T.SCROLL then
			if frame.left then stepNumber(opt, -1) elseif frame.right or frame.select then stepNumber(opt, 1) end
		elseif frame.left then
			leaveOptions()
		elseif frame.right or frame.select then
			if kind == T.KEYBIND_KEYBOARD or kind == T.KEYBIND_CONTROLLER then
				nav.popup = { kind = "bind", option = opt }
			elseif opt.Popup then
				nav.popup = { kind = "confirm", option = opt }
			elseif opt.OnSelect then
				opt.OnSelect()
			end
		end
	end

	local function unbound(opt)
		if opt.NoUnbind then return util.Resolve(opt.Default) end
		-- A raw row hears OnChange(nil); a plain CurrentSetting needs a value to show.
		if type(opt.CurrentSetting) ~= "function" then return -1 end
		return nil
	end

	local function bindInput(frame, opt, capture)
		if frame.reset and not opt.CapturesResetKey then
			nav.popup = nil
			if opt.Default ~= nil then change(opt, util.Resolve(opt.Default)) end
		elseif frame.back or frame.left then
			nav.popup = nil
			change(opt, unbound(opt))
		elseif frame.up or frame.down or frame.right or frame.select then
			nav.buzz()
		else
			local code = capture(opt.Type)
			if code then
				nav.popup = nil
				change(opt, code)
			end
		end
	end

	local function popupInput(frame, capture)
		local popup = nav.popup
		local opt = popup.option
		if popup.kind == "bind" then return bindInput(frame, opt, capture) end
		local confirm = frame.select or frame.right
		if not (confirm or frame.back or frame.left) then return end
		nav.popup = nil
		if popup.kind == "confirm" and confirm and opt.OnSelect then opt.OnSelect() end
	end

	function nav.popupText()
		local popup = nav.popup
		if not popup then return nil end
		if popup.kind == "warning" then return popup.text end
		if popup.option.Popup ~= nil then return popup.option.Popup end
		return keys.bindPopupText(popup.option)
	end

	function api.UpdateCurrentVars()
		api.CurrentCategory = nav.category()
		api.CurrentSubcategory = nav.subcategories()[nav.sub]
		api.CurrentOption = nav.focus == OPTIONS and nav.option() or nil
	end

	function api.GetCurrentFocus()
		return { category = nav.cat, subcategory = nav.sub, option = nav.focus == OPTIONS and nav.opt or nil }
	end

	-- Applies one frame of input; returns "close" when Back leaves the category list.
	function nav.step(frame, capture)
		clampCursor()
		local result
		if #api.MenuData == 0 then
			result = frame.back and "close" or nil
		elseif nav.popup then
			popupInput(frame, capture)
		elseif nav.focus == OPTIONS then
			optionsInput(frame)
		elseif nav.focus == TABS then
			tabsInput(frame)
		else
			result = categoriesInput(frame)
		end
		api.UpdateCurrentVars()
		return result
	end

	return nav
end
