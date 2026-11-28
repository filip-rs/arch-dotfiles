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

-- Hybrid graphics: keep the RTX 3050 powered off unless a game asks for it.
-- Hyprland, GTK4/Qt apps and quickshell otherwise hold /dev/nvidia0 open, so
-- the dGPU never runtime-suspends (~6 W idle). The 680M drives eDP-1 and every
-- external port, so the compositor loses nothing by not seeing the NVIDIA card.
-- Apps only get Mesa's EGL and RADV's Vulkan. A game opts in with:
--   Lutris (wine/linux runners): Configure > System options > GPU > NVIDIA (card0)
--   Steam launch options: VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
--     __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only
--     __GLX_VENDOR_LIBRARY_NAME=nvidia %command%
-- Check: cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status  (suspended)
for n = 0, 7 do
	local f = io.open("/sys/class/drm/card" .. n .. "/device/vendor")
	if f then
		local vendor = f:read("*l")
		f:close()
		if vendor == "0x1002" then
			hl.env("AQ_DRM_DEVICES", "/dev/dri/card" .. n)
			break
		end
	end
end
hl.env("__EGL_VENDOR_LIBRARY_FILENAMES", "/usr/share/glvnd/egl_vendor.d/50_mesa.json")
hl.env("VK_ICD_FILENAMES", "/usr/share/vulkan/icd.d/radeon_icd.json")
-- Qt Multimedia's FFmpeg backend (the quickshell wallpaper picker's video
-- previews) otherwise probes CUDA/VDPAU, loads libcuda and keeps /dev/nvidia0
-- open until quickshell exits. VA-API runs on the 680M. Both are needed: the
-- encoder list is probed on first playback too.
hl.env("QT_FFMPEG_DECODING_HW_DEVICE_TYPES", "vaapi")
hl.env("QT_FFMPEG_ENCODING_HW_DEVICE_TYPES", "vaapi")
hl.on("hyprland.start", function()
	-- systemd/D-Bus-started services (hyprpolkitagent) need them too; the
	-- restart covers the race with autostart.lua starting it.
	hl.exec_cmd("dbus-update-activation-environment --systemd __EGL_VENDOR_LIBRARY_FILENAMES VK_ICD_FILENAMES QT_FFMPEG_DECODING_HW_DEVICE_TYPES QT_FFMPEG_ENCODING_HW_DEVICE_TYPES && systemctl --user restart hyprpolkitagent")
end)
