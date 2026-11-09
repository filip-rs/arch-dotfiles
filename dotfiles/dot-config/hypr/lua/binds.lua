-- Keybinds.
-- Ported from keybindings.conf.

local mod = "SUPER"
local mod5 = "MOD5" -- caps-as-level3 (kb_options = lv3:caps_switch)
local scr = "~/.config/scripts/desktop"
local qs = scr .. "/qs_manager.sh"

-- Descriptions are "Section: what it does". The Guide panel (Super + Ctrl +
-- Shift + G) reads them back from `hyprctl binds -j`, groups them by section
-- and merges binds that share one. Binds without a description are left out.
local function d(text)
	return { description = text }
end

local browser = "librewolf"

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

hl.bind(mod .. " + Q", hl.dsp.exec_cmd("$TERMINAL"), d("Apps: Terminal"))
hl.bind(mod .. " + X", hl.dsp.window.close(), d("Windows: Close"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("nautilus --new-window"), d("Apps: File manager"))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }), d("Windows: Toggle floating"))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen(), d("Windows: Fullscreen"))
hl.bind(mod .. " + P", hl.dsp.window.pseudo(), d("Windows: Pseudo-tile"))
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("wofi"), d("Apps: App launcher"))
hl.bind(mod .. " + O", hl.dsp.exec_cmd("~/.config/quickshell/lock/lock.sh"), d("Session: Lock"))
hl.bind(mod .. " + U", hl.dsp.exec_cmd("wlogout --protocol layer-shell"), d("Session: Power menu"))
hl.bind(mod .. " + CTRL + SHIFT + M", hl.dsp.exit(), { description = "Session: Quit Hyprland (instantly)" })

-- Phone-shaped side window: fullscreen off, float, fixed size, centred.
hl.bind(mod .. " + F5", function()
	hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset" }))
	hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
	hl.dispatch(hl.dsp.window.resize({ x = 480, y = 1080 }))
	hl.dispatch(hl.dsp.window.center())
end, d("Windows: Phone-shaped floating window"))

-- ──────────────────────────── scripts ────────────────────────────

hl.bind(mod .. " + SHIFT + 5", hl.dsp.exec_cmd(scr .. "/screenshot_copy.sh"), d("Tools: Screenshot to clipboard"))
hl.bind(mod .. " + SHIFT + CTRL + S", hl.dsp.exec_cmd(scr .. "/screenshot_save.sh"), d("Tools: Screenshot to file"))
hl.bind(mod .. " + CTRL + SHIFT + 6", hl.dsp.exec_cmd(scr .. "/switch_refreshrate.sh"), d("System: Toggle 60 / 120 Hz"))
hl.bind(mod .. " + CTRL + SHIFT + 7", hl.dsp.exec_cmd(scr .. "/speaker_toggle.sh"), d("System: Speakers / headphones"))
hl.bind(mod .. " + CTRL + SHIFT + 0", hl.dsp.exec_cmd(scr .. "/screen_manager.sh"), d("System: Focus mode (blank side screens)"))

hl.bind(
	mod .. " + SHIFT + R",
	hl.dsp.exec_cmd("~/.local/bin/afk toggle; pkill -RTMIN+9 waybar"),
	d("Tools: AFK lecture capture")
)
hl.bind(
	mod .. " + CTRL + L",
	hl.dsp.exec_cmd("~/.local/bin/login-bind type school"),
	d("Tools: Type school login")
)
hl.bind(
	mod .. " + CTRL + SHIFT + I",
	hl.dsp.exec_cmd("/home/filip/Programming/Bash/mullvad-location-switcher/mullvad-switch.sh next"),
	d("System: Next Mullvad location")
)

-- Idle inhibition (hyprcaffeine). The panel is on SUPER + CTRL + C with the
-- other quickshell panels below; these are the gestures worth having without
-- opening it. They live here rather than in the file `hyprcaffeine keybinds
-- install` writes, because that file binds its menu over SUPER + CTRL + SHIFT
-- + I -- the Mullvad relay switcher directly above -- and is require()d after
-- this one, so it silently won.
hl.bind(mod .. " + CTRL + I", hl.dsp.exec_cmd("hyprcaffeine toggle"), d("System: Caffeine, block suspend"))
hl.bind(
	mod .. " + CTRL + D",
	hl.dsp.exec_cmd("hyprcaffeine monitor toggle"),
	d("System: Caffeine, keep display on")
)
hl.bind(
	mod .. " + CTRL + SHIFT + D",
	hl.dsp.exec_cmd("hyprcaffeine lid toggle"),
	d("System: Caffeine, block lid close")
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
		d("Panels: " .. p.desc)
	)
end

hl.bind(
	mod .. " + SHIFT + T",
	hl.dsp.exec_cmd(qs .. " toggle focustime --anchor=center"),
	d("Panels: Focus time")
)
hl.bind(
	mod .. " + CTRL + SHIFT + G",
	hl.dsp.exec_cmd(qs .. " toggle guide --anchor=center"),
	d("Panels: This guide")
)
hl.bind(mod .. " + CTRL + SPACE", hl.dsp.exec_cmd(scr .. "/qs_menu.sh"), d("Panels: Panel and theme menu"))

-- ─────────────────────────── apps & URLs ─────────────────────────

hl.bind(mod .. " + R", hl.dsp.exec_cmd("obsidian --ozone-platform-hint=auto"), d("Apps: Obsidian"))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("killall waybar && waybar"), d("System: Restart Waybar"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -t -sw"), d("Panels: Notifications"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("wl-color-picker clipboard --no-notify"), d("Tools: Colour picker"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("bemoji -t"), d("Tools: Emoji picker"))

hl.bind("CTRL + SHIFT + ALT + B", hl.dsp.exec_cmd(browser .. " --new-window https://www.bible.com/bible/111/MAT.1.NIV"), d("Links: Bible"))
hl.bind("CTRL + SHIFT + ALT + E", hl.dsp.exec_cmd(browser .. " --new-window https://chat.openai.com/"), d("Links: ChatGPT"))
hl.bind("CTRL + SHIFT + ALT + A", hl.dsp.exec_cmd(browser .. " --new-window https://claude.ai/"), d("Links: Claude"))
hl.bind("CTRL + SHIFT + ALT + L", hl.dsp.exec_cmd(browser .. " --new-window https://linkedin.com/"), d("Links: LinkedIn"))

-- ────────────────────── keyboard-driven pointer ──────────────────

hl.bind(mod .. " + Y", hl.dsp.exec_cmd("wl-kbptr -o modes=floating,bisect -o mode_floating.source=detect"), d("Tools: Keyboard pointer (floating)"))
hl.bind(mod .. " + T", hl.dsp.exec_cmd("wl-kbptr"), d("Tools: Keyboard pointer"))

-- ─────────────────────── æøå + symbol helpers ────────────────────

hl.bind(mod .. " + bracketleft", hl.dsp.exec_cmd("wtype 'å'"), d("Typing: å ø æ"))
hl.bind(mod .. " + semicolon", hl.dsp.exec_cmd("wtype 'ø'"), d("Typing: å ø æ"))
hl.bind(mod .. " + apostrophe", hl.dsp.exec_cmd("wtype 'æ'"), d("Typing: å ø æ"))

-- A list rather than a map so the Guide shows the keys in this order
local symbols = { { "2", "@" }, { "3", "£" }, { "4", "$" }, { "7", "{" }, { "8", "[" }, { "9", "]" }, { "0", "}" } }
for _, s in ipairs(symbols) do
	hl.bind("CTRL + ALT + " .. s[1], hl.dsp.exec_cmd("wtype '" .. s[2] .. "'"), d("Typing: @ £ $ { [ ] }"))
end

-- ──────────────── MOD5 (caps) duplicates of the core binds ───────

hl.bind(mod5 .. " + Q", hl.dsp.exec_cmd("$TERMINAL"))
hl.bind(mod5 .. " + O", hl.dsp.exec_cmd("~/.config/quickshell/lock/lock.sh"))
hl.bind(mod5 .. " + E", hl.dsp.exec_cmd("nautilus --new-window"))
hl.bind(mod5 .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod5 .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod5 .. " + SPACE", hl.dsp.exec_cmd("wofi"))
-- No caps + W: that is how å gets typed on altgr-intl.
hl.bind(mod5 .. " + A", page("l"))
hl.bind(mod5 .. " + D", page("r"))
hl.bind(mod5 .. " + S", hl.dsp.focus({ workspace = "r+1" }))

-- ───────────── volume, brightness and media (SwayOSD popups) ─────────────
-- Hardware keys are bound by keycode, which both keyboards share. The laptop
-- has no media keys, so Super + Alt does the same from the home row.

local osd = "swayosd-client "
local bri = scr .. "/brightness.sh " -- fine steps at the bottom, coarse at the top

local media = {
	{ "code:121", "--output-volume mute-toggle", "Mute", false },
	{ "code:122", "--output-volume -5", "Volume down", true },
	{ "code:123", "--output-volume +5", "Volume up", true },
	{ "XF86AudioMicMute", "--input-volume mute-toggle", "Microphone mute", false },
	{ "XF86AudioPlay", "--playerctl play-pause", "Play / pause", false },
	{ "XF86AudioNext", "--playerctl next", "Next track", false },
	{ "XF86AudioPrev", "--playerctl prev", "Previous track", false },
	{ mod .. " + ALT + SPACE", "--playerctl play-pause", "Play / pause", false },
	{ mod .. " + ALT + L", "--playerctl next", "Next track", false },
	{ mod .. " + ALT + H", "--playerctl prev", "Previous track", false },
	{ mod .. " + ALT + K", "--output-volume +5", "Volume up", true },
	{ mod .. " + ALT + J", "--output-volume -5", "Volume down", true },
	{ mod .. " + ALT + M", "--input-volume mute-toggle", "Microphone mute", false },
}
for _, m in ipairs(media) do
	hl.bind(m[1], hl.dsp.exec_cmd(osd .. m[2]), { locked = true, repeating = m[4], description = "Media: " .. m[3] })
end

hl.bind("code:232", hl.dsp.exec_cmd(bri .. "down"), { locked = true, repeating = true, description = "System: Brightness down" })
hl.bind("code:233", hl.dsp.exec_cmd(bri .. "up"), { locked = true, repeating = true, description = "System: Brightness up" })
hl.bind(mod .. " + code:232", hl.dsp.exec_cmd(bri .. "min"), { locked = true, description = "System: Brightness to minimum" })
hl.bind(mod .. " + code:233", hl.dsp.exec_cmd(bri .. "max"), { locked = true, description = "System: Brightness to maximum" })
hl.bind("code:237", hl.dsp.exec_cmd(bri .. "kbd-down"), { repeating = true, description = "System: Keyboard backlight down" })
hl.bind("code:238", hl.dsp.exec_cmd(bri .. "kbd-up"), { repeating = true, description = "System: Keyboard backlight up" })

-- ───────────────────── workspaces & focus ────────────────────────
-- Laid out like niri: the column tape scrolls sideways, workspaces stack
-- vertically on W/S. A/D page a whole screen; H/L step one column.

for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }), d("Workspaces: Switch to workspace"))
	if i ~= 5 then -- SUPER + SHIFT + 5 is the screenshot
		hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), d("Workspaces: Move window to workspace"))
	end
end

hl.bind(mod .. " + W", hl.dsp.focus({ workspace = "r-1" }), d("Workspaces: Workspace up"))
hl.bind(mod .. " + S", hl.dsp.focus({ workspace = "r+1" }), d("Workspaces: Workspace down"))
hl.bind(mod .. " + SHIFT + W", hl.dsp.window.move({ workspace = "r-1" }), d("Workspaces: Move window up a workspace"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "r+1" }), d("Workspaces: Move window down a workspace"))

hl.bind(mod .. " + A", page("l"), d("Columns: Page one screen left"))
hl.bind(mod .. " + D", page("r"), d("Columns: Page one screen right"))
hl.bind(mod .. " + SHIFT + A", hl.dsp.layout("swapcol l"), d("Columns: Move column left"))
hl.bind(mod .. " + SHIFT + D", hl.dsp.layout("swapcol r"), d("Columns: Move column right"))

-- Column sizing and shaping.
hl.bind(mod .. " + minus", hl.dsp.layout("colresize -0.1"), { repeating = true, description = "Columns: Narrow column" })
hl.bind(mod .. " + equal", hl.dsp.layout("colresize +0.1"), { repeating = true, description = "Columns: Widen column" })
hl.bind(mod .. " + Z", hl.dsp.layout("colresize +conf"), d("Columns: Cycle column width"))
hl.bind(mod .. " + SHIFT + F", hl.dsp.layout("colresize 1.0"), d("Columns: Maximize column (Z to go back)"))
hl.bind(mod .. " + C", hl.dsp.layout("center"), d("Columns: Centre column"))
hl.bind(mod .. " + comma", hl.dsp.layout("consume_or_expel prev"), d("Columns: Pull window into column"))
hl.bind(mod .. " + period", hl.dsp.layout("consume_or_expel next"), d("Columns: Push window out of column"))

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "r+1" }), d("Workspaces: Scroll through workspaces"))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "r-1" }), d("Workspaces: Scroll through workspaces"))
hl.bind(mod .. " + SHIFT + mouse_down", hl.dsp.layout("focus r"), d("Columns: Scroll through columns"))
hl.bind(mod .. " + SHIFT + mouse_up", hl.dsp.layout("focus l"), d("Columns: Scroll through columns"))

hl.bind(mod .. " + H", hl.dsp.focus({ direction = "l" }), d("Windows: Move focus"))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }), d("Windows: Move focus"))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "u" }), d("Windows: Move focus"))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "d" }), d("Windows: Move focus"))

hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }), d("Windows: Move window"))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }), d("Windows: Move window"))
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }), d("Windows: Move window"))
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }), d("Windows: Move window"))

hl.bind("ALT + TAB", hl.dsp.window.cycle_next(), d("Windows: Cycle windows"))

-- ─────────────────────────── mouse binds ─────────────────────────

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Windows: Drag window" })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Windows: Resize window" })
hl.bind(mod .. " + SHIFT + mouse:272", hl.dsp.window.resize(), { mouse = true, description = "Windows: Resize window" })
