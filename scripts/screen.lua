-- Screen size, corners and the HUD offset (0-10, the game's Options.HUDOffset x 10).
local STEP_X, STEP_Y = 2, 1.2 -- pixels a corner moves inward per offset step

return function(api, util)
	function api.GetScreenSize()
		return Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight())
	end

	function api.GetScreenCenter()
		return Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2)
	end

	function api.GetOffset()
		return util.Clamp(math.floor(Options.HUDOffset * 10 + 0.5), 0, 10)
	end

	function api.SetOffset(n)
		n = util.Clamp(util.Round(n), 0, 10)
		api.Config.General.HudOffset = n
		Options.HUDOffset = n / 10
	end

	local function inward(x, y, dirX, dirY, offset)
		offset = offset or api.GetOffset()
		return Vector(x + dirX * STEP_X * offset, y + dirY * STEP_Y * offset)
	end

	function api.GetScreenTopLeft(offset)
		return inward(0, 0, 1, 1, offset)
	end

	function api.GetScreenTopRight(offset)
		return inward(Isaac.GetScreenWidth(), 0, -1, 1, offset)
	end

	function api.GetScreenBottomLeft(offset)
		return inward(0, Isaac.GetScreenHeight(), 1, -1, offset)
	end

	function api.GetScreenBottomRight(offset)
		return inward(Isaac.GetScreenWidth(), Isaac.GetScreenHeight(), -1, -1, offset)
	end
end
