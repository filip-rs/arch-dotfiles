-- Keybinds.
-- Ported from keybindings.conf.

local mod = "SUPER"
local mod5 = "MOD5" -- caps-as-level3 (kb_options = lv3:caps_switch)
local scr = "~/.config/scripts/desktop"
local qs = scr .. "/qs_manager.sh"

local browser = "brave-beta"

-- Page the scrolling tape one screen sideways (Super + A/D).
--
-- Right stops once the view sits just past the last column: the whole screen
-- is empty (wallpaper), and a window opened there becomes the next column
-- right where you are looking, with no snap. Left stops at the first column.
--
-- Plain `move ±px` can't rest in empty space: it focuses the column under the
-- middle of the screen, and that focus re-fits the view onto it. So the last
-- page finishes with `move +col` from the last column, which Hyprland
-- special-cases: view to the end of the tape, focus dropped.

-- Where the tape is relative to the view, from the tiled windows' target
-- positions (so it is right even mid-animation). nil on an empty workspace.
local function tape_geometry()
	local m = hl.get_active_monitor()
	local ws = hl.get_active_workspace()
	if not m or not ws then
		return nil
	end

	-- Window boxes exclude the border; the tape's outer edges include it.
	local border = hl.get_config("general:border_size")
	local first, last
	for _, w in ipairs(hl.get_windows({ workspace = ws.id })) do
		if not w.floating and not w.hidden then
			first = math.min(first or math.huge, w.at.x - border)
			last = math.max(last or -math.huge, w.at.x + w.size.x + border)
		end
	end
	if not first then
		return nil
	end

	-- The tape scrolls inside the usable area: the screen minus bars and
	-- gaps_out. width/height are raw mode pixels, so swap them when rotated
	-- 90/270 and undo the scale.
	local gaps = hl.get_config("general:gaps_out")
	local px = (m.transform % 2 == 1) and m.height or m.width
	local left = m.x + m.reserved.left + gaps.left
	local right = m.x + px / m.scale - m.reserved.right - gaps.right

	return {
		page = right - left,
		room_left = left - first, -- how far the tape's start is left of the view
		room_right = last - left, -- how far the tape's end is right of the view's left edge
	}
end

-- `move +N` shifts the windows right, i.e. pans the view left.
local function move_tape(px)
	hl.dispatch(hl.dsp.layout(string.format("move %+d", px < 0 and -math.floor(-px + 0.5) or math.floor(px + 0.5))))
end

local function page(dir)
	return function()
		local t = tape_geometry()
		if not t then
			return
		end

		if dir == "l" then
			if t.room_left >= 1 then
				move_tape(math.min(t.page, t.room_left))
			end
		elseif t.room_right > t.page then
			move_tape(-t.page)
		elseif t.room_right >= 1 then
			-- Last page: this lands focus (and the view) on the last column...
			move_tape(-t.room_right)
			-- ...so this has no next column and goes to the end of the tape.
			hl.dispatch(hl.dsp.layout("move +col"))
		end
	end
end

-- ───────────────────────────── core ─────────────────────────────

hl.bind(mod .. " + Q", hl.dsp.exec_cmd("alacritty"))
hl.bind(mod .. " + X", hl.dsp.window.close())
hl.bind(mod .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("wofi"))
hl.bind(mod .. " + O", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + U", hl.dsp.exec_cmd("wlogout --protocol layer-shell"))
hl.bind(mod .. " + SHIFT + M", hl.dsp.exit())

-- Phone-shaped side window: fullscreen off, float, fixed size, centred.
hl.bind(mod .. " + F5", function()
	hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset" }))
	hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
	hl.dispatch(hl.dsp.window.resize({ x = 480, y = 1080 }))
	hl.dispatch(hl.dsp.window.center())
end, { description = "Phone-shaped floating window" })

-- ──────────────────────────── scripts ────────────────────────────

hl.bind(mod .. " + SHIFT + 5", hl.dsp.exec_cmd(scr .. "/screenshot_copy.sh"))
hl.bind(mod .. " + SHIFT + CTRL + S", hl.dsp.exec_cmd(scr .. "/screenshot_save.sh"))
hl.bind(mod .. " + CTRL + SHIFT + 6", hl.dsp.exec_cmd(scr .. "/switch_refreshrate.sh"))
hl.bind(mod .. " + CTRL + SHIFT + 7", hl.dsp.exec_cmd(scr .. "/speaker_toggle.sh"))
hl.bind(mod .. " + CTRL + SHIFT + 0", hl.dsp.exec_cmd(scr .. "/screen_manager.sh"))

hl.bind(
	mod .. " + SHIFT + R",
	hl.dsp.exec_cmd("~/.local/bin/afk toggle"),
	{ description = "Toggle AFK lecture capture" }
)
hl.bind(
	mod .. " + CTRL + L",
	hl.dsp.exec_cmd("~/.local/bin/login-bind type school"),
	{ description = "Type school login" }
)
hl.bind(
	mod .. " + CTRL + SHIFT + I",
	hl.dsp.exec_cmd("/home/filip/Programming/Bash/mullvad-location-switcher/mullvad-switch.sh next"),
	{ description = "Next Mullvad location" }
)

-- Idle inhibition (hyprcaffeine). The panel is on SUPER + CTRL + C with the
-- other quickshell panels below; these are the gestures worth having without
-- opening it. They live here rather than in the file `hyprcaffeine keybinds
-- install` writes, because that file binds its menu over SUPER + CTRL + SHIFT
-- + I -- the Mullvad relay switcher directly above -- and is require()d after
-- this one, so it silently won.
hl.bind(mod .. " + CTRL + I", hl.dsp.exec_cmd("hyprcaffeine toggle"), { description = "Caffeine: block suspend" })
hl.bind(
	mod .. " + CTRL + D",
	hl.dsp.exec_cmd("hyprcaffeine monitor toggle"),
	{ description = "Caffeine: keep display on" }
)
hl.bind(
	mod .. " + CTRL + SHIFT + D",
	hl.dsp.exec_cmd("hyprcaffeine lid toggle"),
	{ description = "Caffeine: block lid close" }
)

-- ───────────────────────── quickshell panels ─────────────────────
-- Keybind invocations get the centre anchor; waybar icons pass their own.

local panels = {
	{ key = "M", target = "monitors", desc = "Monitors" },
	{ key = "Q", target = "music", desc = "Music" },
	{ key = "B", target = "battery", desc = "Battery" },
	{ key = "W", target = "wallpaper", desc = "Wallpaper picker" },
	{ key = "S", target = "calendar", desc = "Calendar" },
	{ key = "N", target = "network", desc = "Network" },
	{ key = "V", target = "volume", desc = "Volume" },
	{ key = "C", target = "caffeine", desc = "Caffeine" },
}

for _, p in ipairs(panels) do
	hl.bind(
		mod .. " + CTRL + " .. p.key,
		hl.dsp.exec_cmd(qs .. " toggle " .. p.target .. " --anchor=center"),
		{ description = "Quickshell: " .. p.desc }
	)
end

hl.bind(
	mod .. " + SHIFT + T",
	hl.dsp.exec_cmd(qs .. " toggle focustime --anchor=center"),
	{ description = "Quickshell: Focus time" }
)
hl.bind(
	mod .. " + CTRL + SHIFT + G",
	hl.dsp.exec_cmd(qs .. " toggle guide --anchor=center"),
	{ description = "Quickshell: Guide" }
)
hl.bind(mod .. " + CTRL + SPACE", hl.dsp.exec_cmd(scr .. "/qs_menu.sh"), { description = "Quickshell module menu" })

-- ─────────────────────────── apps & URLs ─────────────────────────

hl.bind(mod .. " + R", hl.dsp.exec_cmd("obsidian --ozone-platform-hint=auto"))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("killall waybar && waybar"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("wl-color-picker clipboard --no-notify"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("bemoji -t"))

hl.bind("CTRL + SHIFT + B", hl.dsp.exec_cmd(browser .. " --new-window https://www.bible.com/bible/111/MAT.1.NIV"))
hl.bind("CTRL + SHIFT + ALT + E", hl.dsp.exec_cmd(browser .. " --new-window https://chat.openai.com/"))
hl.bind("CTRL + SHIFT + ALT + A", hl.dsp.exec_cmd(browser .. " --new-window https://claude.ai/"))
hl.bind("CTRL + SHIFT + ALT + L", hl.dsp.exec_cmd(browser .. " --new-window https://linkedin.com/"))

-- ────────────────────── keyboard-driven pointer ──────────────────

hl.bind(mod .. " + Y", hl.dsp.exec_cmd("wl-kbptr -o modes=floating,bisect -o mode_floating.source=detect"))
hl.bind(mod .. " + T", hl.dsp.exec_cmd("wl-kbptr"))

-- ─────────────────────── æøå + symbol helpers ────────────────────

hl.bind(mod .. " + bracketleft", hl.dsp.exec_cmd("wtype 'å'"))
hl.bind(mod .. " + semicolon", hl.dsp.exec_cmd("wtype 'ø'"))
hl.bind(mod .. " + apostrophe", hl.dsp.exec_cmd("wtype 'æ'"))

local symbols = { ["2"] = "@", ["3"] = "£", ["4"] = "$", ["7"] = "{", ["8"] = "[", ["9"] = "]", ["0"] = "}" }
for key, sym in pairs(symbols) do
	hl.bind("CTRL + ALT + " .. key, hl.dsp.exec_cmd("wtype '" .. sym .. "'"))
end

-- ──────────────── MOD5 (caps) duplicates of the core binds ───────

hl.bind(mod5 .. " + Q", hl.dsp.exec_cmd("alacritty"))
hl.bind(mod5 .. " + O", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod5 .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind(mod5 .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod5 .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod5 .. " + SPACE", hl.dsp.exec_cmd("wofi"))
-- No caps + W: that is how å gets typed on altgr-intl.
hl.bind(mod5 .. " + A", page("l"))
hl.bind(mod5 .. " + D", page("r"))
hl.bind(mod5 .. " + S", hl.dsp.focus({ workspace = "r+1" }))

-- ──────────── ROG G15 Strix (2021) hardware keys, by keycode ─────

hl.bind("code:156", hl.dsp.exec_cmd("rog-control-center")) -- Armoury Crate key
hl.bind("code:211", hl.dsp.exec_cmd("asusctl profile -n; pkill -SIGRTMIN+8 waybar")) -- fan profile, FN+F5
hl.bind("code:210", hl.dsp.exec_cmd("asusctl led-mode -n")) -- keyboard RGB profile, FN+F4

hl.bind("code:121", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind(
	"code:122",
	hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"code:123",
	hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)

hl.bind("code:232", hl.dsp.exec_cmd("brightnessctl set 1%-"), { locked = true, repeating = true })
hl.bind("code:233", hl.dsp.exec_cmd("brightnessctl set 1%+"), { locked = true, repeating = true })
hl.bind(mod .. " + code:232", hl.dsp.exec_cmd("brightnessctl set 100%-"), { locked = true })
hl.bind(mod .. " + code:233", hl.dsp.exec_cmd("brightnessctl set 50%+"), { locked = true })

hl.bind("code:237", hl.dsp.exec_cmd("brightnessctl -d asus::kbd_backlight set 33%-"), { repeating = true })
hl.bind("code:238", hl.dsp.exec_cmd("brightnessctl -d asus::kbd_backlight set 33%+"), { repeating = true })

-- ───────────────────── workspaces & focus ────────────────────────
-- Laid out like niri: the column tape scrolls sideways, workspaces stack
-- vertically on W/S. A/D page a whole screen; H/L step one column.

for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	if i ~= 5 then -- SUPER + SHIFT + 5 is the screenshot
		hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
	end
end

hl.bind(mod .. " + W", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + S", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mod .. " + SHIFT + W", hl.dsp.window.move({ workspace = "r-1" }))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "r+1" }))

hl.bind(mod .. " + A", page("l"), { description = "Page tape left" })
hl.bind(mod .. " + D", page("r"), { description = "Page tape right" })
hl.bind(mod .. " + SHIFT + A", hl.dsp.layout("swapcol l"))
hl.bind(mod .. " + SHIFT + D", hl.dsp.layout("swapcol r"))

-- Column sizing and shaping.
hl.bind(mod .. " + minus", hl.dsp.layout("colresize -0.1"), { repeating = true })
hl.bind(mod .. " + equal", hl.dsp.layout("colresize +0.1"), { repeating = true })
hl.bind(mod .. " + Z", hl.dsp.layout("colresize +conf"))
hl.bind(mod .. " + SHIFT + F", hl.dsp.layout("colresize 1.0")) -- maximize column; Z to go back
hl.bind(mod .. " + C", hl.dsp.layout("center"))
hl.bind(mod .. " + comma", hl.dsp.layout("consume_or_expel prev"))
hl.bind(mod .. " + period", hl.dsp.layout("consume_or_expel next"))

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + SHIFT + mouse_down", hl.dsp.layout("focus r"))
hl.bind(mod .. " + SHIFT + mouse_up", hl.dsp.layout("focus l"))

hl.bind(mod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "d" }))

hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))

hl.bind("ALT + TAB", hl.dsp.window.cycle_next())

-- ─────────────────────────── mouse binds ─────────────────────────

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mod .. " + SHIFT + mouse:272", hl.dsp.window.resize(), { mouse = true })
