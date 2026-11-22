-- Pure helpers shared by the modules; modconfig.lua publishes the public ones on the API table.
local util = {}

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

-- Writes src over dst, recursing into tables both have.
function util.MergeOver(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			util.MergeOver(dst[k], v)
		else
			dst[k] = util.CopyTable(v)
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

function util.WrapLines(lines, width, measure)
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

return util
