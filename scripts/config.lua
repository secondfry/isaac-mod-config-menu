-- Config and ConfigDefault: the values of helper-created settings, and their JSON save form.
local json = require("json")

-- Old dependents read these at the top level; they live in Config.General.
local GENERAL_KEYS = { HudOffset = true, Overlays = true, ChargeBars = true, BigBooks = true }

return function(api, util)
	local warned = {}
	local function warnOnce(key)
		if warned[key] then return end
		warned[key] = true
		print("[Config Menu] Config." .. key .. " is deprecated, use Config.General." .. key)
	end

	local redirect = {
		__index = function(t, key)
			if not GENERAL_KEYS[key] then return nil end
			warnOnce(key)
			local general = rawget(t, "General")
			return general and general[key]
		end,
		__newindex = function(t, key, value)
			if not GENERAL_KEYS[key] then return rawset(t, key, value) end
			warnOnce(key)
			rawget(t, "General")[key] = value
		end,
	}

	-- With Options present, General only mirrors the game's own settings.
	local function generalMirror()
		if not Options then return { HudOffset = 0, Overlays = true, ChargeBars = false, BigBooks = true, Announcer = 0 } end
		return {
			HudOffset = util.Clamp(math.floor(Options.HUDOffset * 10 + 0.5), 0, 10),
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
		["Mod Config Menu"] = {},
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
		local merged = util.MergeOver(util.CopyTable(api.ConfigDefault), saved)
		util.FillTable(merged, api.Config)
		if Options then merged.General = generalMirror() end
		api.Config = setmetatable(merged, redirect)
		return api.Config
	end
end
