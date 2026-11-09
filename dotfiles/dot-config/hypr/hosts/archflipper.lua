-- archflipper: the laptop (ROG Flow, eDP-1). Loaded by lua/hosts.lua.

-- Mirror the internal panel onto HDMI (projectors, TVs).
hl.monitor({
	output = "HDMI-A-1",
	mode = "1920x1080@60",
	position = "auto",
	scale = 1.25,
	mirror = "eDP-1",
})

-- ASUS hardware keys, by keycode (asusd / rog-control-center).
hl.bind("code:156", hl.dsp.exec_cmd("rog-control-center"), { description = "System: ROG Control Center" })
hl.bind("code:211", hl.dsp.exec_cmd("asusctl profile -n"), { description = "System: Next fan profile" })
hl.bind("code:210", hl.dsp.exec_cmd("asusctl led-mode -n"), { description = "System: Next keyboard RGB mode" })
