-- Assertions for the Lua tests.
function eq(actual, expected, what)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
	end
end

function ok(value, what)
	if not value then error((what or "condition") .. " is not true", 2) end
end

function raises(fn, pattern, what)
	local success, message = pcall(fn)
	if success then error((what or "call") .. " did not raise", 2) end
	if pattern and not tostring(message):find(pattern) then
		error(string.format("%s raised %q, wanted %q", what or "call", tostring(message), pattern), 2)
	end
	return message
end
