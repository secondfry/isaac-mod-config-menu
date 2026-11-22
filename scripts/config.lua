-- Config and ConfigDefault: the values of helper-created settings, and their JSON save form.
local json = require("json")

-- Old dependents read these at the top level; they live in Config.General.
local GENERAL_KEYS = { HudOffset = true, Overlays = true, ChargeBars = true, BigBooks = true }

-- Writes src over dst, recursing into tables both have.
local function mergeOver(dst, src, copy)
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			mergeOver(dst[k], v, copy)
		else
			dst[k] = copy(v)
		end
	end
	return dst
end

return function(api, util)
	local function deprecated(key)
		util.deprecated("Config." .. key, "Config.General." .. key)
	end

	local redirect = {
		__index = function(t, key)
			if not GENERAL_KEYS[key] then return nil end
			deprecated(key)
			local general = rawget(t, "General")
			return general and general[key]
		end,
		__newindex = function(t, key, value)
			if not GENERAL_KEYS[key] then return rawset(t, key, value) end
			deprecated(key)
			rawget(t, "General")[key] = value
		end,
	}

	-- General only mirrors the game's own settings.
	local function generalMirror()
		return {
			HudOffset = api.GetOffset(),
			Overlays = true,
			ChargeBars = Options.ChargeBars,
			BigBooks = true,
			Announcer = Options.AnnouncerVoiceMode,
		}
	end

	api.ConfigDefault = setmetatable({
		LastBackPressed = Keyboard.KEY_ESCAPE,
		LastSelectPressed = Keyboard.KEY_ENTER,
		General = generalMirror(),
		[util.NAME] = {},
	}, redirect)
	api.Config = setmetatable(util.CopyTable(api.ConfigDefault), redirect)

	function api.GetSave()
		return json.encode(api.Config)
	end

	-- Defaults first, saved values over them, and a current value only where neither has the key.
	function api.LoadSave(input)
		local saved = input
		if type(input) == "string" then
			local ok, decoded = pcall(json.decode, input)
			saved = ok and decoded or nil
		end
		if type(saved) ~= "table" then return nil end
		local merged = mergeOver(util.CopyTable(api.ConfigDefault), saved, util.CopyTable)
		util.FillTable(merged, api.Config)
		merged.General = generalMirror()
		api.Config = setmetatable(merged, redirect)
		return api.Config
	end
end
