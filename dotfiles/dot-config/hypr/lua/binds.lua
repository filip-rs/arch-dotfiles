-- Keybinds.
-- Ported from keybindings.conf.

local mod   = "SUPER"
local mod5  = "MOD5"     -- caps-as-level3 (kb_options = lv3:caps_switch)
local scr   = "~/.config/hypr/scripts"
local qs    = scr .. "/qs_manager.sh"

local browser = "brave-beta"

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

hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(scr .. "/screenshot_copy.sh"))
hl.bind(mod .. " + SHIFT + CTRL + S", hl.dsp.exec_cmd(scr .. "/screenshot_save.sh"))
hl.bind(mod .. " + CTRL + SHIFT + SPACE", hl.dsp.exec_cmd(scr .. "/switch_layout.sh"))
hl.bind(mod .. " + CTRL + SHIFT + 6", hl.dsp.exec_cmd(scr .. "/switch_refreshrate.sh"))
hl.bind(mod .. " + CTRL + SHIFT + 7", hl.dsp.exec_cmd(scr .. "/speaker_toggle.sh"))
hl.bind(mod .. " + CTRL + SHIFT + 0", hl.dsp.exec_cmd(scr .. "/screen_manager.sh"))

hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.local/bin/afk toggle"),
    { description = "Toggle AFK lecture capture" })
hl.bind(mod .. " + CTRL + L", hl.dsp.exec_cmd("~/.local/bin/login-bind type school"),
    { description = "Type school login" })
hl.bind(mod .. " + CTRL + SHIFT + I",
    hl.dsp.exec_cmd("/home/filip/Programming/Bash/mullvad-location-switcher/mullvad-switch.sh next"),
    { description = "Next Mullvad location" })

-- Idle inhibition (hyprcaffeine). The panel is on SUPER + CTRL + C with the
-- other quickshell panels below; these are the gestures worth having without
-- opening it. They live here rather than in the file `hyprcaffeine keybinds
-- install` writes, because that file binds its menu over SUPER + CTRL + SHIFT
-- + I -- the Mullvad relay switcher directly above -- and is require()d after
-- this one, so it silently won.
hl.bind(mod .. " + CTRL + I", hl.dsp.exec_cmd("hyprcaffeine toggle"),
    { description = "Caffeine: block suspend" })
hl.bind(mod .. " + CTRL + D", hl.dsp.exec_cmd("hyprcaffeine monitor toggle"),
    { description = "Caffeine: keep display on" })
hl.bind(mod .. " + CTRL + SHIFT + D", hl.dsp.exec_cmd("hyprcaffeine lid toggle"),
    { description = "Caffeine: block lid close" })

-- ───────────────────────── quickshell panels ─────────────────────
-- Keybind invocations get the centre anchor; waybar icons pass their own.

local panels = {
    { key = "M",     target = "monitors",  desc = "Monitors" },
    { key = "Q",     target = "music",     desc = "Music" },
    { key = "B",     target = "battery",   desc = "Battery" },
    { key = "W",     target = "wallpaper", desc = "Wallpaper picker" },
    { key = "S",     target = "calendar",  desc = "Calendar" },
    { key = "N",     target = "network",   desc = "Network" },
    { key = "V",     target = "volume",    desc = "Volume" },
    { key = "C",     target = "caffeine",  desc = "Caffeine" },
}

for _, p in ipairs(panels) do
    hl.bind(mod .. " + CTRL + " .. p.key,
        hl.dsp.exec_cmd(qs .. " toggle " .. p.target .. " --anchor=center"),
        { description = "Quickshell: " .. p.desc })
end

hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd(qs .. " toggle focustime --anchor=center"),
    { description = "Quickshell: Focus time" })
hl.bind(mod .. " + CTRL + SHIFT + G", hl.dsp.exec_cmd(qs .. " toggle guide --anchor=center"),
    { description = "Quickshell: Guide" })
hl.bind(mod .. " + CTRL + SPACE", hl.dsp.exec_cmd(scr .. "/qs_menu.sh"),
    { description = "Quickshell module menu" })

-- ─────────────────────────── apps & URLs ─────────────────────────

hl.bind(mod .. " + W", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + R", hl.dsp.exec_cmd("obsidian --ozone-platform-hint=auto"))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("killall waybar && waybar"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("wl-color-picker clipboard --no-notify"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("bemoji -t"))

hl.bind("CTRL + SHIFT + B",
    hl.dsp.exec_cmd(browser .. " --new-window https://www.bible.com/bible/111/MAT.1.NIV"))
hl.bind("CTRL + SHIFT + ALT + E",
    hl.dsp.exec_cmd(browser .. " --new-window https://chat.openai.com/"))
hl.bind("CTRL + SHIFT + ALT + A",
    hl.dsp.exec_cmd(browser .. " --new-window https://claude.ai/"))
hl.bind("CTRL + SHIFT + ALT + L",
    hl.dsp.exec_cmd(browser .. " --new-window https://linkedin.com/"))

-- ────────────────────── keyboard-driven pointer ──────────────────

hl.bind(mod .. " + Y", hl.dsp.exec_cmd("wl-kbptr -o modes=floating,bisect -o mode_floating.source=detect"))
hl.bind(mod .. " + T", hl.dsp.exec_cmd("wl-kbptr"))

-- ─────────────────────── æøå + symbol helpers ────────────────────

hl.bind(mod .. " + bracketleft", hl.dsp.exec_cmd("wtype 'å'"))
hl.bind(mod .. " + semicolon",   hl.dsp.exec_cmd("wtype 'ø'"))
hl.bind(mod .. " + apostrophe",  hl.dsp.exec_cmd("wtype 'æ'"))

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
hl.bind(mod5 .. " + D", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mod5 .. " + A", hl.dsp.focus({ workspace = "r-1" }))

-- ──────────── ROG G15 Strix (2021) hardware keys, by keycode ─────

hl.bind("code:156", hl.dsp.exec_cmd("rog-control-center"))                    -- Armoury Crate key
hl.bind("code:211", hl.dsp.exec_cmd("asusctl profile -n; pkill -SIGRTMIN+8 waybar")) -- fan profile, FN+F5
hl.bind("code:210", hl.dsp.exec_cmd("asusctl led-mode -n"))                   -- keyboard RGB profile, FN+F4

hl.bind("code:121", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("code:122", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("code:123", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })

hl.bind("code:232", hl.dsp.exec_cmd("brightnessctl set 1%-"), { locked = true, repeating = true })
hl.bind("code:233", hl.dsp.exec_cmd("brightnessctl set 1%+"), { locked = true, repeating = true })
hl.bind(mod .. " + code:232", hl.dsp.exec_cmd("brightnessctl set 100%-"), { locked = true })
hl.bind(mod .. " + code:233", hl.dsp.exec_cmd("brightnessctl set 50%+"), { locked = true })

hl.bind("code:237", hl.dsp.exec_cmd("brightnessctl -d asus::kbd_backlight set 33%-"), { repeating = true })
hl.bind("code:238", hl.dsp.exec_cmd("brightnessctl -d asus::kbd_backlight set 33%+"), { repeating = true })

-- ───────────────────── workspaces & focus ────────────────────────

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + D", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mod .. " + A", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + SHIFT + D", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(mod .. " + SHIFT + A", hl.dsp.window.move({ workspace = "r-1" }))

hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special(""))

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
