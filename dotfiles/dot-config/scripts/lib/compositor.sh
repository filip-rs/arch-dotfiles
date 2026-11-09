#!/usr/bin/env bash
# compositor.sh — the compositor (Hyprland) calls the desktop scripts share.
#
# Source it from bash scripts:
#     source "$HOME/.config/scripts/lib/compositor.sh"
#     for o in $(list_outputs); do ...; done
# or run it from QML / Python / other shells:
#     ~/.config/scripts/lib/compositor.sh monitors-json
#
# Hyprland's config is Lua, so dispatches are written as Lua (`hl.dsp...`).

compositor() {
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then echo hyprland; else echo unknown; fi
}

# Names of enabled outputs, one per line.
list_outputs() {
    hyprctl -j monitors 2>/dev/null | jq -r '.[].name'
}

focused_output() {
    hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused) | .name' | head -1
}

# The output under the pointer, else the focused one.
pointer_output() {
    local pos name
    pos=$(hyprctl cursorpos -j 2>/dev/null)
    if [ -n "$pos" ]; then
        name=$(hyprctl monitors -j 2>/dev/null | jq -r --argjson c "$pos" '
            .[] | select(
                $c.x >= .x and $c.x < (.x + (.width / .scale)) and
                $c.y >= .y and $c.y < (.y + (.height / .scale))
            ) | .name' 2>/dev/null | head -1)
        [ -n "$name" ] && { printf '%s\n' "$name"; return; }
    fi
    focused_output
}

# Enabled outputs as `hyprctl monitors -j` (name, width, height, refreshRate,
# x, y, scale, focused, ...). width/height are the mode's physical pixels.
monitors_json() {
    hyprctl -j monitors 2>/dev/null || echo '[]'
}

# Output power: output_power NAME on|off (DPMS)
output_power() {
    hyprctl dispatch "hl.dsp.dpms({ action = \"$2\", monitor = \"$1\" })" >/dev/null
}

# Is the output currently on? Exit status 0 = on.
output_is_on() {
    [ "$(hyprctl -j monitors 2>/dev/null | jq --arg n "$1" '.[] | select(.name == $n) | .dpmsStatus')" = "true" ]
}

# Live, non-persistent output configuration:
#   set_output NAME WxH@RATE X Y SCALE
set_output() {
    hyprctl eval "hl.monitor({ output = '$1', mode = '$2', position = '${3}x${4}', scale = $5 })" >/dev/null
}

focus_workspace() {
    hyprctl dispatch "hl.dsp.focus({ workspace = $1 })" >/dev/null
}

move_window_to_workspace() {
    hyprctl dispatch "hl.dsp.window.move({ workspace = $1 })" >/dev/null
}

# Make Hyprland pick up regenerated theme files (colors.lua).
reload_compositor() {
    hyprctl reload >/dev/null 2>&1
    return 0
}

# Executed directly: dispatch `compositor.sh some-command args` to some_command.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    cmd="${1:-compositor}"
    shift 2>/dev/null
    fn="${cmd//-/_}"
    if [ "$(type -t "$fn")" = "function" ]; then
        "$fn" "$@"
    else
        echo "usage: $0 {compositor|list-outputs|focused-output|pointer-output|monitors-json|output-power|output-is-on|set-output|focus-workspace|move-window-to-workspace|reload-compositor}" >&2
        exit 1
    fi
fi
