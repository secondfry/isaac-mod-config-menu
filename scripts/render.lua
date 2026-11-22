-- Draws the open menu, the first-run hint and the warning lines. Layout numbers are approximate by design.
local ANM2 = "gfx/configmenu/menu.anm2"
local POPUP_LAYER = 1
local TITLE = "Config Menu"
local PANEL_W, PANEL_H = 400, 228
local LIST_TOP = 32
local CAT_X, CAT_W, CAT_ROW, CAT_ROWS = 10, 116, 16, 9
local OPT_X, OPT_W, OPT_ROW, OPT_ROWS = 136, 254, 14, 10
local TAB_H, TABS_SHOWN = 16, 3
local INFO_TOP, INFO_LINE, INFO_LINES, INFO_W, INFO_W_WIDE = 184, 12, 3, 260, 376
local SLIDER_W = 56
local PAPER_W, PAPER_H, PAPER_MARGIN = 80, 16, 4
local POPUP_W, POPUP_LINE = 180, 10
local INK = { 0.24, 0.17, 0.11 }
local RESTART_LINE = "Restart the game to apply some changes"
local RERUN_LINE = "Start a new run to apply some changes"

return function(api, util, nav)
	local T = api.OptionType
	local render = {}
	local fonts, sprite, popupSprite, popupGfx
	local catScroll, optScroll = 0, 0

	local function menuConfig() return api.Config["Mod Config Menu"] or {} end

	function api.GetMenuAnm2Sprite(animation, frame, color)
		local s = Sprite()
		s:Load(ANM2, true)
		s:SetFrame(animation, frame or 0)
		if color then s.Color = color end
		return s
	end

	function api.DrawFont(font, text, x, y, color, boxWidth, center)
		font:DrawStringUTF8(tostring(text), x, y, color or KColor(INK[1], INK[2], INK[3], 1), boxWidth or 0, center)
	end

	local function loadFonts()
		if fonts then return fonts end
		local extended = api.DLC >= 4
		local function load(path)
			local f = Font()
			f:Load(path)
			return f
		end
		fonts = {
			row = load(extended and "font/teammeatex/teammeatex10.fnt" or "font/teammeatfont10.fnt"),
			big = load(extended and "font/teammeatex/teammeatex12.fnt" or "font/teammeatfont12.fnt"),
			title = load("font/teammeatfont16bold.fnt"),
			hint = load("font/pftempestasevencondensed.fnt"),
		}
		return fonts
	end

	local function ink(alpha, rgb)
		rgb = type(rgb) == "table" and rgb or INK
		return KColor(rgb[1], rgb[2], rgb[3], alpha)
	end

	local function text(font, str, x, y, color, width)
		font:DrawStringUTF8(str, x, y, color, width or 0, width ~= nil)
	end

	local function draw(animation, frame, x, y, scale)
		sprite = sprite or api.GetMenuAnm2Sprite(animation, frame)
		sprite:SetFrame(animation, frame)
		sprite.Scale = scale or Vector(1, 1)
		sprite:Render(Vector(x, y))
	end

	local function measure(font)
		return function(s) return font:GetStringWidthUTF8(s) end
	end

	local function scrolled(scroll, cursor, rows)
		if cursor <= scroll then return cursor - 1 end
		if cursor > scroll + rows then return cursor - rows end
		return scroll
	end

	local function scrollArrows(x, top, bottom, above, below)
		if above then draw("CursorUp", 0, x, top) end
		if below then draw("CursorDown", 0, x, bottom) end
	end

	local function drawCategories(f, ox, oy)
		local data = api.MenuData
		catScroll = scrolled(catScroll, nav.cat, CAT_ROWS)
		for i = catScroll + 1, math.min(#data, catScroll + CAT_ROWS) do
			local category = data[i]
			local y = oy + LIST_TOP + (i - catScroll - 1) * CAT_ROW
			local here = i == nav.cat
			if category then text(f.big, tostring(category.Name or ""), ox + CAT_X, y, ink(here and 1 or 0.5), CAT_W) end
			if here and nav.focus == nav.CATEGORIES then draw("CursorRight", 0, ox + CAT_X - 6, y + 4) end
		end
		local x = ox + CAT_X + CAT_W / 2
		scrollArrows(x, oy + LIST_TOP - 6, oy + LIST_TOP + CAT_ROWS * CAT_ROW, catScroll > 0, catScroll + CAT_ROWS < #data)
	end

	-- Returns where the option rows start and how many fit.
	local function drawTabs(f, ox, oy)
		local top = oy + LIST_TOP
		if not nav.hasTabBar() then return top, OPT_ROWS end
		local subs = nav.subcategories()
		local first = util.Clamp(nav.sub - 1, 1, math.max(1, #subs - TABS_SHOWN + 1))
		local tabW = OPT_W / TABS_SHOWN
		for i = first, math.min(#subs, first + TABS_SHOWN - 1) do
			local here = i == nav.sub
			text(f.row, tostring(subs[i].Name or ""), ox + OPT_X + (i - first) * tabW, top, ink(here and 1 or 0.5), tabW)
		end
		if nav.focus == nav.TABS then
			draw("CursorLeft", 0, ox + OPT_X - 6, top + 4)
			draw("CursorRight", 0, ox + OPT_X + OPT_W, top + 4)
		end
		draw("Divider", 0, ox + OPT_X, top + TAB_H - 3)
		return top + TAB_H, OPT_ROWS - 1
	end

	local function drawSliderLine(font, opt, before, value, after, x, y, color)
		local frame = util.Clamp(math.floor(tonumber(value) or 0), 0, 10)
		local wb, wa = font:GetStringWidthUTF8(before), font:GetStringWidthUTF8(after)
		local startX = x + (OPT_W - (wb + SLIDER_W + wa)) / 2
		text(font, before, startX, y, color)
		draw(opt.AltSlider and "Slider2" or "Slider1", frame, startX + wb, y + 3)
		text(font, after, startX + wb + SLIDER_W, y, color)
	end

	local function drawRow(f, opt, label, x, y, here, inOptions)
		local font = opt.Type == T.TITLE and f.big or f.row
		local color = ink(here and 1 or (inOptions and 0.7 or 0.5), opt.Color)
		local before, value, after = label:match("^(.-)%$scroll(%d+)(.*)$")
		if not before and opt.Type == T.SCROLL then before, value, after = label .. " ", util.Resolve(opt.CurrentSetting), "" end
		if before then
			drawSliderLine(font, opt, before, value, after, x, y, color)
		else
			text(font, label, x, y, color, OPT_W)
		end
		if util.Resolve(opt.ShowStrikeout) then
			local width = font:GetStringWidthUTF8(label)
			draw("Strikeout", 0, x + (OPT_W - width) / 2, y + 7, Vector(width, 1))
		end
		if here then draw("CursorRight", 0, x - 4, y + 4) end
	end

	-- Every visible row's Display runs once per frame wherever the cursor is; EID relies on it.
	local function drawOptions(f, ox, top, rows)
		local options = nav.options()
		local inOptions = nav.focus == nav.OPTIONS
		optScroll = scrolled(optScroll, inOptions and nav.opt or 1, rows)
		for i = optScroll + 1, math.min(#options, optScroll + rows) do
			local opt = options[i]
			if opt and nav.isKnown(opt) and opt.Type ~= T.SPACE and opt.Display ~= nil then
				local y = top + (i - optScroll - 1) * OPT_ROW
				local here = inOptions and i == nav.opt
				local label = util.Resolve(opt.Display, here, inOptions, Vector(ox + OPT_X + OPT_W / 2, y))
				drawRow(f, opt, tostring(label), ox + OPT_X, y, here, inOptions)
			end
		end
		local x = ox + OPT_X + OPT_W / 2
		scrollArrows(x, top - 6, top + rows * OPT_ROW, optScroll > 0, optScroll + rows < #options)
	end

	local function infoSource()
		if nav.focus == nav.OPTIONS then
			local opt = nav.option()
			return opt and opt.Info
		end
		if nav.focus == nav.TABS then
			local sub = nav.subcategories()[nav.sub]
			return sub and sub.Info
		end
		local category = nav.category()
		return category and category.Info, category and category.IsOld
	end

	local function controlsShown()
		if not menuConfig().ShowControls then return false end
		local opt = nav.focus == nav.OPTIONS and nav.option()
		return not (opt and util.Resolve(opt.HideControls))
	end

	local function drawInfo(f, ox, oy)
		local info, isOld = infoSource()
		if info == nil then return end
		local width = controlsShown() and INFO_W or INFO_W_WIDE
		local lines = util.WrapLines(util.ConvertDisplayToTextTable(info), width, measure(f.hint))
		local color = isOld and KColor(0.75, 0.1, 0.1, 1) or ink(1)
		for i = 1, math.min(#lines, INFO_LINES) do
			text(f.hint, lines[i], ox + (PANEL_W - width) / 2, oy + INFO_TOP + (i - 1) * INFO_LINE, color, width)
		end
	end

	local function paper(f, animation, x, y, configKey, action)
		draw(animation, 0, x, y)
		local key = api.KeyboardToString[api.Config[configKey]] or "?"
		text(f.hint, key .. " " .. action, x + 12, y + 3, ink(1), PAPER_W - 14)
	end

	local function drawControls(f, w, h)
		if not controlsShown() then return end
		local y = h - PAPER_MARGIN - PAPER_H
		local closes = nav.focus == nav.CATEGORIES and not nav.popup
		paper(f, closes and "Exit" or "Back", PAPER_MARGIN, y, "LastBackPressed", closes and "close" or "back")
		paper(f, "Select", w - PAPER_MARGIN - PAPER_W, y, "LastSelectPressed", "select")
	end

	local function drawOffsetMarkers()
		local opt = nav.focus == nav.OPTIONS and nav.option()
		if not (opt and util.Resolve(opt.ShowOffset)) then return end
		local corners = {
			OffsetTopLeft = api.GetScreenTopLeft(), OffsetTopRight = api.GetScreenTopRight(),
			OffsetBottomLeft = api.GetScreenBottomLeft(), OffsetBottomRight = api.GetScreenBottomRight(),
		}
		for animation, at in pairs(corners) do draw(animation, 0, at.X, at.Y) end
	end

	local function drawWarnings(f, w, h)
		local lines = {}
		if nav.restartWarning then lines[#lines + 1] = RESTART_LINE end
		if nav.rerunWarning then lines[#lines + 1] = RERUN_LINE end
		for i, line in ipairs(lines) do
			text(f.hint, line, 0, h - api.WarningOffset - (i - 1) * 10, KColor(0.9, 0.15, 0.15, 1), w)
		end
	end

	local function drawPopup(f, w, h)
		if not nav.popup then return end
		local opt = nav.popup.option
		local gfx = opt and opt.PopupGfx or api.PopupGfx.THIN_SMALL
		if gfx ~= popupGfx then
			popupSprite = popupSprite or api.GetMenuAnm2Sprite("Popup", 0)
			popupSprite:ReplaceSpritesheet(POPUP_LAYER, gfx)
			popupSprite:LoadGraphics()
			popupGfx = gfx
		end
		popupSprite:Render(Vector(w / 2, h / 2))
		local width = opt and opt.PopupWidth or POPUP_W
		local lines = util.WrapLines(util.ConvertDisplayToTextTable(nav.popupText()), width, measure(f.hint))
		local top = h / 2 - #lines * POPUP_LINE / 2
		for i, line in ipairs(lines) do
			text(f.hint, line, w / 2 - width / 2, top + (i - 1) * POPUP_LINE, ink(1), width)
		end
	end

	function render.menu()
		local f = loadFonts()
		local w, h = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
		local ox, oy = math.floor((w - PANEL_W) / 2), math.floor((h - PANEL_H) / 2)
		draw("Idle", 0, ox, oy)
		text(f.title, TITLE, ox, oy + 6, ink(1), PANEL_W)
		drawCategories(f, ox, oy)
		drawOptions(f, ox, drawTabs(f, ox, oy))
		drawInfo(f, ox, oy)
		drawControls(f, w, h)
		drawOffsetMarkers()
		drawWarnings(f, w, h)
		drawPopup(f, w, h)
	end

	function render.hint(alpha)
		local f = loadFonts()
		local w, h = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
		local key = api.KeyboardToString[menuConfig().OpenMenuKeyboard] or "?"
		local offset = DeadSeaScrollsMenu and api.WarningOffsetDSS or api.WarningOffset
		text(f.hint, "Press " .. key .. " to open the " .. TITLE, 0, h - offset, KColor(1, 1, 0, alpha), w)
	end

	return render
end
