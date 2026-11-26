-- Helpers and the mod's name shared by the modules; modconfig.lua publishes the public ones.
local util = {}

-- The mod's name, its page and its Config section; EID reads Config["Mod Config Menu"].HideHudInMenu.
util.NAME = "Mod Config Menu"
util.NAME_YET_ANOTHER = "Yet Another Mod Config Menu" -- the Workshop title; NAME stays for EID's Config lookup
util.REPORT = "Please report it: discord.gg/5KvKaUpsvR (Fry Labs) or github.com/secondfry/isaac-mod-config-menu/issues"
util.UNCATEGORIZED = "Uncategorized" -- the default subcategory; a category with only this one has no tab bar
util.SCROLL_MAX = 10 -- SCROLL rows run 0 to this

local warned = {}
function util.warnOnce(key, message)
	if warned[key] then return end
	warned[key] = true
	local line = "[" .. util.NAME .. "] " .. message
	print(line)
	Isaac.DebugString(line)
	return true
end

function util.deprecated(name, replacement)
	util.warnOnce(name, name .. " is deprecated, use " .. replacement)
end

function util.Round(n, places)
	if not places or places == 0 then return math.floor(n + 0.5) end
	local scale = 10 ^ places
	return math.floor(n * scale + 0.5) / scale
end

function util.RoundVector(v)
	return Vector(util.Round(v.X), util.Round(v.Y))
end

function util.Clamp(n, low, high)
	return math.max(low, math.min(high, n))
end

function util.CopyTable(t)
	if type(t) ~= "table" then return t end
	local copy = {}
	for k, v in pairs(t) do copy[k] = util.CopyTable(v) end
	return copy
end

-- Adds what dst lacks from src, recursing into tables both have; dst's own values stay.
function util.FillTable(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = util.CopyTable(v)
		elseif type(dst[k]) == "table" and type(v) == "table" then
			util.FillTable(dst[k], v)
		end
	end
	return dst
end

function util.Resolve(value, ...)
	if type(value) == "function" then return value(...) end
	return value
end

-- A string, array of strings or function becomes an array of lines, split at "$newline".
function util.ConvertDisplayToTextTable(display, ...)
	display = util.Resolve(display, ...)
	local parts = type(display) == "table" and display or { display }
	local lines = {}
	for _, part in ipairs(parts) do
		local text = tostring(util.Resolve(part))
		for line in (text .. "$newline"):gmatch("(.-)%$newline") do lines[#lines + 1] = line end
	end
	return lines
end

return util
