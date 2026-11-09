-- Autostart.
-- Ported from the exec-once block in hyprland.conf.

hl.on("hyprland.start", function()
	-- D-Bus-started apps (Nautilus from wofi/the dock, portals, polkit agent)
	-- do not inherit Hyprland's env; without these they fall back to stock themes.
	hl.exec_cmd("dbus-update-activation-environment --systemd GTK_THEME QT_QPA_PLATFORMTHEME")

	hl.exec_cmd("systemctl --user start hyprpolkitagent")

	-- Tray applets
	hl.exec_cmd("blueman-applet")

	hl.exec_cmd("hyprpm reload -n")
	hl.exec_cmd("iio-hyprland") -- automatic screen rotation

	-- Shell components
	hl.exec_cmd("swaync")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("waybar")
	hl.exec_cmd("env -u QT_QPA_PLATFORMTHEME quickshell -p ~/.config/quickshell/Main.qml")
	hl.exec_cmd("hypridle")

	-- AirPods control daemon. librepods-ctl and the me.kavishdevar.* D-Bus
	-- interfaces only work while this is running.
	hl.exec_cmd("librepods --hide")

	-- Focus Time panel data (Super + Shift + T). flock keeps it to one copy.
	hl.exec_cmd("flock -n $XDG_RUNTIME_DIR/focus_daemon.lock python3 ~/.config/quickshell/focustime/focus_daemon.py")

	-- 10-band EQ PipeWire filter-chain (this is what replaces easyeffects).
	hl.exec_cmd("~/.config/quickshell/music/equalizer.sh apply")

	hl.dispatch(hl.dsp.focus({ workspace = 3 }))
end)
