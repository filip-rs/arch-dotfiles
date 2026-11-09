-- Per-machine settings that live in git: hosts/<hostname>.lua, e.g.
-- hosts/archflipper.lua (laptop) and hosts/archbased.lua (desktop).
--
-- host.lua is a different thing: gitignored, and only holds the monitor lines
-- scripts/desktop/monitor_apply.sh writes (see lua/monitors.lua).

local f = io.open("/etc/hostname")
local name = f and f:read("*l")
if f then
	f:close()
end

if name and name ~= "" then
	local file = io.open(os.getenv("HOME") .. "/.config/hypr/hosts/" .. name .. ".lua")
	if file then
		file:close()
		-- Not pcall'd: a mistake in a host file should show in configerrors
		require("hosts." .. name)
	end
end
