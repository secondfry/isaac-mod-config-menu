-- Draws the open menu, the first-run hint, the warning lines and the other-copy and unsupported-call notices; layout numbers are approximate.
local ANM2 = "gfx/configmenu/menu.anm2"
local FONT = "font/cjk/lanapixel.fnt" -- the game's CJK font, for all text (user's choice)
local POPUP_LAYER = 1
local PANEL_W, PANEL_H = 400, 228
local LIST_TOP = 32
local CAT_X, CAT_W, CAT_ROW, CAT_ROWS = 10, 116, 16, 9
local OPT_X, OPT_W, OPT_ROW, OPT_ROWS = 136, 254, 14, 10
local TAB_H, TABS_SHOWN = 16, 3
local INFO_TOP, INFO_LINE, INFO_LINES, INFO_W, INFO_W_WIDE = 184, 12, 3, 260, 376
local SLIDER_W = 56
local PAPER_W, PAPER_H, PAPER_MARGIN = 80, 16, 4
local POPUP_W, POPUP_LINE = 180, 10
local INK = { 1, 0.8, 0.2 } -- orange-yellow, shared by all menu text and the open hint (user's choice)
local OLD_RGB = { 0.75, 0.1, 0.1 }
local WARNING_RGB = { 0.9, 0.15, 0.15 }
local NOTICE_RGB = { 1, 0.5, 0.5 }
local RESTART_LINE = "Restart the game to apply some changes"
local RERUN_LINE = "Start a new run to apply some changes"
local NOTICE_X, NOTICE_Y, NOTICE_LINE = 70, 30, 10 -- placed like MinimapAPI's own warnings
local NOTICE_LINES = {
	"More than one Mod Config Menu mod is enabled.",
	"Only one Mod Config Menu mod should be enabled at a time.",
}

local function wrapLines(lines, width, measure)
	local wrapped = {}
	for _, line in ipairs(lines) do
		local current = ""
		for word in line:gmatch("%S+") do
			local candidate = current == "" and word or current .. " " .. word
			if current ~= "" and measure(candidate) > width then
				wrapped[#wrapped + 1] = current
				current = word
			else
				current = candidate
			end
		end
		wrapped[#wrapped + 1] = current
	end
	return wrapped
end

return function(api, util, nav)
	local T = api.OptionType
	local render = {}
	local loadedFont, sprite, popupSprite, popupGfx
	local catScroll, optScroll = 0, 0

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

	local function font()
		if loadedFont then return loadedFont end
		loadedFont = Font()
		loadedFont:Load(FONT)
		return loadedFont
	end

	local function ink(alpha, rgb)
		rgb = type(rgb) == "table" and rgb or INK
		return KColor(rgb[1], rgb[2], rgb[3], alpha)
	end

	local function text(str, x, y, color, width)
		api.DrawFont(font(), str, x, y, color, width, width ~= nil)
	end

	local function textWidth(s) return font():GetStringWidthUTF8(s) end

	local function draw(animation, frame, x, y, scale)
		sprite = sprite or api.GetMenuAnm2Sprite(animation, frame)
		sprite:SetFrame(animation, frame)
		sprite.Scale = scale or Vector(1, 1)
		sprite:Render(Vector(x, y))
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

	local function drawCategories(ox, oy)
		local order = nav.order()
		catScroll = scrolled(catScroll, nav.position(order), CAT_ROWS)
		for position = catScroll + 1, math.min(#order, catScroll + CAT_ROWS) do
			local id = order[position]
			local y = oy + LIST_TOP + (position - catScroll - 1) * CAT_ROW
			local here = id == nav.cat
			text(tostring(api.MenuData[id].Name or ""), ox + CAT_X, y, ink(here and 1 or 0.5), CAT_W)
			if here and nav.focus == nav.CATEGORIES then draw("CursorRight", 0, ox + CAT_X - 6, y + 4) end
		end
		local x = ox + CAT_X + CAT_W / 2
		scrollArrows(x, oy + LIST_TOP - 6, oy + LIST_TOP + CAT_ROWS * CAT_ROW, catScroll > 0, catScroll + CAT_ROWS < #order)
	end

	-- Returns where the option rows start and how many fit.
	local function drawTabs(ox, oy)
		local top = oy + LIST_TOP
		if not nav.hasTabBar() then return top, OPT_ROWS end
		local subs = nav.subcategories()
		local first = util.Clamp(nav.sub - 1, 1, math.max(1, #subs - TABS_SHOWN + 1))
		local tabW = OPT_W / TABS_SHOWN
		for i = first, math.min(#subs, first + TABS_SHOWN - 1) do
			local here = i == nav.sub
			text(tostring(subs[i].Name or ""), ox + OPT_X + (i - first) * tabW, top, ink(here and 1 or 0.5), tabW)
		end
		if nav.focus == nav.TABS then
			draw("CursorLeft", 0, ox + OPT_X - 6, top + 4)
			draw("CursorRight", 0, ox + OPT_X + OPT_W, top + 4)
		end
		draw("Divider", 0, ox + OPT_X, top + TAB_H - 3)
		return top + TAB_H, OPT_ROWS - 1
	end

	local function drawSliderLine(opt, before, value, after, x, y, color)
		local frame = util.Clamp(math.floor(tonumber(value) or 0), 0, util.SCROLL_MAX)
		local wb, wa = textWidth(before), textWidth(after)
		local startX = x + (OPT_W - (wb + SLIDER_W + wa)) / 2
		text(before, startX, y, color)
		draw(opt.AltSlider and "Slider2" or "Slider1", frame, startX + wb, y + 3)
		text(after, startX + wb + SLIDER_W, y, color)
	end

	local function drawRow(opt, label, x, y, here, inOptions)
		local color = ink(here and 1 or (inOptions and 0.7 or 0.5), opt.Color)
		local before, value, after = label:match("^(.-)%$scroll(%d+)(.*)$")
		if not before and opt.Type == T.SCROLL then before, value, after = label .. " ", util.Resolve(opt.CurrentSetting), "" end
		if before then
			drawSliderLine(opt, before, value, after, x, y, color)
		else
			text(label, x, y, color, OPT_W)
		end
		if util.Resolve(opt.ShowStrikeout) then
			local width = textWidth(label)
			draw("Strikeout", 0, x + (OPT_W - width) / 2, y + 7, Vector(width, 1))
		end
		if here then draw("CursorRight", 0, x - 4, y + 4) end
	end

	-- Every visible row's Display runs once per frame wherever the cursor is; EID relies on it.
	local function drawOptions(ox, top, rows)
		local options = nav.options()
		local inOptions = nav.focus == nav.OPTIONS
		optScroll = scrolled(optScroll, inOptions and nav.opt or 1, rows)
		for i = optScroll + 1, math.min(#options, optScroll + rows) do
			local opt = options[i]
			if nav.isDrawn(opt) then
				local y = top + (i - optScroll - 1) * OPT_ROW
				local here = inOptions and i == nav.opt
				local label = util.Resolve(opt.Display, here, inOptions, Vector(ox + OPT_X + OPT_W / 2, y))
				drawRow(opt, tostring(label), ox + OPT_X, y, here, inOptions)
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
		if not api.Config[util.NAME].ShowControls then return false end
		local opt = nav.focus == nav.OPTIONS and nav.option()
		return not (opt and util.Resolve(opt.HideControls))
	end

	local function drawInfo(ox, oy)
		local info, isOld = infoSource()
		if info == nil then return end
		local width = controlsShown() and INFO_W or INFO_W_WIDE
		local lines = wrapLines(util.ConvertDisplayToTextTable(info), width, textWidth)
		local color = ink(1, isOld and OLD_RGB or nil)
		for i = 1, math.min(#lines, INFO_LINES) do
			text(lines[i], ox + (PANEL_W - width) / 2, oy + INFO_TOP + (i - 1) * INFO_LINE, color, width)
		end
	end

	local function paper(animation, x, y, configKey, action)
		draw(animation, 0, x, y)
		local key = api.KeyboardToString[api.Config[configKey]] or "?"
		text(key .. " " .. action, x + 12, y + 3, ink(1), PAPER_W - 14)
	end

	local function drawControls(w, h)
		if not controlsShown() then return end
		local y = h - PAPER_MARGIN - PAPER_H
		local closes = nav.focus == nav.CATEGORIES and not nav.popup
		paper(closes and "Exit" or "Back", PAPER_MARGIN, y, "LastBackPressed", closes and "close" or "back")
		paper("Select", w - PAPER_MARGIN - PAPER_W, y, "LastSelectPressed", "select")
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

	local function drawPopup(w, h)
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
		local lines = wrapLines(util.ConvertDisplayToTextTable(nav.popupText()), width, textWidth)
		local top = h / 2 - #lines * POPUP_LINE / 2
		for i, line in ipairs(lines) do
			text(line, w / 2 - width / 2, top + (i - 1) * POPUP_LINE, ink(1), width)
		end
	end

	function render.menu()
		local w, h = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
		local ox, oy = math.floor((w - PANEL_W) / 2), math.floor((h - PANEL_H) / 2)
		draw("Idle", 0, ox, oy)
		text(util.NAME, ox, oy + 6, ink(1), PANEL_W)
		drawCategories(ox, oy)
		drawOptions(ox, drawTabs(ox, oy))
		drawInfo(ox, oy)
		drawControls(w, h)
		drawOffsetMarkers()
		drawPopup(w, h)
	end

	function render.hint(alpha)
		local w, h = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
		local key = api.KeyboardToString[api.Config[util.NAME].OpenMenuKeyboard] or "?"
		local offset = DeadSeaScrollsMenu and api.WarningOffsetDSS or api.WarningOffset
		text("Press " .. key .. " to open the " .. util.NAME, 0, h - offset, ink(alpha), w)
	end

	-- Drawn open or closed: they stay until the restart or next run they ask for.
	function render.warnings()
		local w, h = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
		local lines = {}
		if nav.restartWarning then lines[#lines + 1] = RESTART_LINE end
		if nav.rerunWarning then lines[#lines + 1] = RERUN_LINE end
		for i, line in ipairs(lines) do
			text(line, 0, h - api.WarningOffset - (i - 1) * 10, ink(1, WARNING_RGB), w)
		end
	end

	function render.notice()
		for i, line in ipairs(NOTICE_LINES) do
			text(line, NOTICE_X, NOTICE_Y + (i - 1) * NOTICE_LINE, ink(1, NOTICE_RGB))
		end
	end

	-- Below the other-copy notice, wrapped to the screen so the long report line stays readable.
	function render.unsupported(messages)
		local width = Isaac.GetScreenWidth() - 2 * NOTICE_X
		local y = NOTICE_Y + (#NOTICE_LINES + 1) * NOTICE_LINE
		for _, line in ipairs(wrapLines(messages, width, textWidth)) do
			text(line, NOTICE_X, y, ink(1, NOTICE_RGB))
			y = y + NOTICE_LINE
		end
	end

	return render
end
