-- Autostart.
-- Ported from the exec-once block in hyprland.conf.

hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start hyprpolkitagent")

	-- Tray applets
	hl.exec_cmd("blueman-applet")

	hl.exec_cmd("hyprpm reload -n")
	hl.exec_cmd("iio-hyprland") -- automatic screen rotation

	-- Shell components
	hl.exec_cmd("swaync")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("waybar")
	hl.exec_cmd("quickshell -p ~/.config/hypr/scripts/quickshell/Main.qml")
	hl.exec_cmd("hypridle")

	-- AirPods control daemon. librepods-ctl and the me.kavishdevar.* D-Bus
	-- interfaces only work while this is running.
	hl.exec_cmd("librepods --hide")

	hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")

	-- 10-band EQ PipeWire filter-chain (this is what replaces easyeffects).
	hl.exec_cmd("~/.config/hypr/scripts/quickshell/music/equalizer.sh apply")

	-- restore wallpaper + theme on login.
	-- hl.exec_cmd("~/.config/hypr/scripts/init.sh")

	hl.dispatch(hl.dsp.focus({ workspace = 3 }))
end)
