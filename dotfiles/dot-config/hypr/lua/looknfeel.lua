-- General appearance: gaps, borders, decoration, layouts.
-- Ported from the general{} / decoration{} / misc{} / dwindle{} blocks.

local theme = require("lua.theme")

hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 7,
		border_size = 1,

		col = {
			active_border = theme.border,
			inactive_border = theme.border_inactive,
		},

		layout = "scrolling",
	},

	decoration = {
		rounding = theme.rounding,

		blur = {
			enabled = true,
			size = 3,
			passes = 4,
			new_optimizations = true,
		},
	},

	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		animate_manual_resizes = true,
		vrr = 0,
	},

	-- Niri-style scrolling tape; values mirror the layout{} block in
	-- niri/config.kdl. Super A/D walk the columns, Super W/S the workspaces.
	scrolling = {
		column_width = 0.5,
		explicit_column_widths = "0.333, 0.5, 0.667", -- Super + Z cycles these
		fullscreen_on_one_column = false, -- a lone window stays half-width, like niri
		focus_fit_method = 1, -- scroll just enough to fit (niri center-focused-column "never")
		wrap_focus = false,
		wrap_swapcol = false,
	},

	-- Unused while layout = "scrolling"; kept for switching back.
	dwindle = {
		preserve_split = true,
	},

	ecosystem = {
		no_update_news = true,
	},
})
