-- Autostart.
-- Ported from the exec-once block in hyprland.conf.

hl.on("hyprland.start", function()
	-- Tray applets
	hl.exec_cmd("blueman-applet")
	-- nm-applet is deliberately not started: the bar's own network module and
	-- the quickshell wifi panel cover everything it did. It ran with
	-- --no-agent, so it was never the secret agent either -- NetworkPopup.qml
	-- passes the passphrase inline via `nmcli device wifi connect ... password`.
	-- Re-enable by uncommenting if you ever want the indicator back:
	-- hl.exec_cmd("nm-applet --no-agent --indicator")

	-- Serial adapter kernel module.
	-- NOTE: this needs a passwordless sudo rule to actually work. The proper
	-- home for it is /etc/modules-load.d/cp210x.conf (single line: cp210x).
	hl.exec_cmd("sudo modprobe cp210x")

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

	-- Optional: restore wallpaper + theme on login.
	-- hl.exec_cmd("~/.config/hypr/scripts/init.sh")

	hl.dispatch(hl.dsp.focus({ workspace = 3 }))
end)
