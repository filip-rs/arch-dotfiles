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

		layout = "dwindle",
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

	dwindle = {
		preserve_split = true,
	},

	ecosystem = {
		no_update_news = true,
	},
})
