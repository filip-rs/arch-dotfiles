-- Monitors and workspace pinning.
--
-- Per-machine monitor lines live in host.lua (gitignored), which is loaded at
-- the end of this file. See host.lua.example for the template.

-- Fallback for any monitor without an explicit rule: preferred mode, placed to
-- the right of the others.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Laptop: mirror the internal panel onto HDMI (projectors, TVs).
hl.monitor({
	output = "HDMI-A-1",
	mode = "1920x1080@60",
	position = "auto",
	scale = 1.25,
	mirror = "eDP-1",
})

-- Workspace -> output pinning.
--   1-5   HDMI-A-1  (laptop / mirrored external)
--   6-10  DP-1      (desktop centre)
--   11-15 DP-3      (desktop right)
local pinned = {
	["HDMI-A-1"] = { 1, 2, 3, 4, 5 },
	["DP-1"] = { 6, 7, 8, 9, 10 },
	["DP-3"] = { 11, 12, 13, 14, 15 },
}

for output, workspaces in pairs(pinned) do
	for _, id in ipairs(workspaces) do
		hl.workspace_rule({
			workspace = tostring(id),
			monitor = output,
			persistent = false,
		})
	end
end

-- Machine-specific monitor layout + session env.
pcall(require, "host")
