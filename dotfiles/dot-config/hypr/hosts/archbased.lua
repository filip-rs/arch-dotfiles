-- archbased: the desktop (DP-2 left, DP-1 centre, DP-3 right). Loaded by lua/hosts.lua.

-- Workspace -> output pinning.
--   1-5   HDMI-A-1  (mirrored TV)
--   6-10  DP-1      (centre)
--   11-15 DP-3      (right)
local pinned = {
	["HDMI-A-1"] = { 1, 2, 3, 4, 5 },
	["DP-1"] = { 6, 7, 8, 9, 10 },
	["DP-3"] = { 11, 12, 13, 14, 15 },
}
for output, workspaces in pairs(pinned) do
	for _, id in ipairs(workspaces) do
		hl.workspace_rule({ workspace = tostring(id), monitor = output, persistent = false })
	end
end

-- Discord floats on the left screen.
hl.window_rule({
	name = "discord",
	match = { initial_title = "discord" },
	float = true,
	center = true,
	size = { "monitor_w*0.5", "monitor_h*0.5" },
	monitor = "DP-2",
})
