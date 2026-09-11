-- Plugin config: hyprgrass (touch gestures) + hyprexpo (workspace overview).
-- Ported from hyprgrass.conf and hyprexpo.conf.
--
-- NEITHER PLUGIN IS CURRENTLY INSTALLED. This file is a parked translation of
-- the old hyprlang configs so the settings survive; it has never been run
-- against a loaded plugin. Everything -- settings included -- sits behind an
-- `is the plugin loaded?` check, so with the plugins absent this file is a
-- no-op. That check is load-bearing: hl.config() does not reject unknown
-- plugin keys, it registers them and Hyprland reports them later, so an
-- unguarded settings block leaves a dozen `unknown config key` lines in
-- `hyprctl configerrors` permanently.
--
-- Corollary for reinstall day: if the plugins load but none of these settings
-- apply, suspect the guard -- hl.plugin.<name> may not be populated at
-- config-parse time, since autostart.lua only runs `hyprpm reload -n` at
-- hyprland.start. Dropping the two `if has(...)` lines is the first thing to
-- try. The notes below mark the rest of the guesswork.
--
-- Two things changed shape in the hyprlang -> Lua move:
--   * the settings block was `plugin { touch_gestures { ... } }`; in Lua it is
--     keyed by plugin name, `plugin = { hyprgrass = { ... } }`.
--   * binds were pattern strings (`edge:d:u`, `swipe:3:ld`); in Lua they are
--     pattern tables. The docs list direction values as full words
--     ("left"/"right"/"up"/"down") but show single letters in one example
--     ("origin = \"d\""). Full words are used below -- if the plugin rejects
--     them, try the single-letter forms.

local function has(plugin)
	return type(hl.plugin) == "table" and type(hl.plugin[plugin]) == "table"
end

-- ─────────────────────────── hyprexpo ────────────────────────────

if has("hyprexpo") then
hl.config({
	plugin = {
		hyprexpo = {
			columns = 3,
			gap_size = 5,
			bg_col = "rgb(111111)",
			-- [center/first] [workspace], e.g. `first 1` or `center m+1`
			workspace_method = "center 5",

			-- gesture_distance = 300, -- how far is the "max" for the gesture
		},
	},
})
end

-- ─────────────────────────── hyprgrass ───────────────────────────

if has("hyprgrass") then
hl.config({
	plugin = {
		hyprgrass = {
			-- The default is too low on tablet screens; 4.0 is the
			-- recommended value there.
			sensitivity = 4.0,

			-- must be >= 3
			workspace_swipe_fingers = 3,

			-- Swiping workspaces from an edge, separate from
			-- workspace_swipe_fingers and usable at the same time.
			-- Values: l, r, u, d -- anything else disables it.
			workspace_swipe_edge = "f",

			long_press_delay = 400, -- milliseconds

			-- Resize windows by long-pressing on borders and gaps. If
			-- general:resize_on_border is on, general:extend_border_grab_area
			-- applies to floating windows.
			resize_on_border_long_press = true,

			edge_margin = 10, -- px from the edge that counts as an edge

			-- Emulate touchpad swipes when swiping in a direction that does
			-- not trigger a workspace swipe. Only fires when the finger count
			-- equals workspace_swipe_fingers.
			emulate_touchpad_swipe = false,

			experimental = {
				-- Send proper cancel events to windows instead of hacky
				-- touch_up events. Not recommended -- it crashed a few times.
				send_cancel = 0,
			},
		},
	},
})

	local g = hl.plugin.hyprgrass

	-- On-screen keyboard, swiped up from the bottom edge / away at the top.
	-- The old config also had a SIGRTMIN+2 toggle variant, kept for reference:
	--   kill -34 $(ps -C wvkbd-mobintl)
	g.bind({
		pattern = { kind = "edge", origin = "down", direction = "up" },
		action = hl.dsp.exec_cmd("wvkbd-mobintl"),
	})
	g.bind({
		pattern = { kind = "edge", origin = "up", direction = "down" },
		action = hl.dsp.exec_cmd("killall wvkbd-mobintl"),
	})

	-- Swipe in from the left/right edge to change workspace.
	g.bind({
		pattern = { kind = "edge", origin = "right", direction = "left" },
		action = hl.dsp.focus({ workspace = "+1" }),
	})
	g.bind({
		pattern = { kind = "edge", origin = "left", direction = "right" },
		action = hl.dsp.focus({ workspace = "-1" }),
	})

	-- Volume on the right edge.
	g.bind({
		pattern = { kind = "edge", origin = "right", direction = "down" },
		action = hl.dsp.exec_cmd("pamixer -d 10"),
	})
	g.bind({
		pattern = { kind = "edge", origin = "right", direction = "up" },
		action = hl.dsp.exec_cmd("pamixer -i 10"),
	})

	g.bind({
		pattern = { kind = "swipe", fingers = 4, direction = "down" },
		action = hl.dsp.window.close(),
	})

	-- Diagonal swipe (was `swipe:3:ld` -- l/r had to come before d/u). The Lua
	-- docs do not list a diagonal direction value, so "leftdown" is a guess;
	-- this is the most likely line to need fixing.
	g.bind({
		pattern = { kind = "swipe", fingers = 3, direction = "leftdown" },
		action = hl.dsp.exec_cmd("alacritty"),
	})

	g.bind({
		pattern = { kind = "tap", fingers = 3 },
		action = hl.dsp.exec_cmd("wofi"),
	})

	-- Long-press acts as a mouse bind (was hyprgrass-bindm).
	g.bind({
		pattern = { kind = "longpress", fingers = 2 },
		action = hl.dsp.window.drag(),
		mouse = true,
	})
	g.bind({
		pattern = { kind = "longpress", fingers = 3 },
		action = hl.dsp.window.resize(),
		mouse = true,
	})

	-- Was `exec-once = wvkbd-mobintl` at the top of hyprgrass.conf: the OSK
	-- only makes sense alongside the gestures, so it lives here rather than in
	-- autostart.lua.
	hl.on("hyprland.start", function()
		hl.exec_cmd("wvkbd-mobintl")
	end)
end
