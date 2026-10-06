#!/usr/bin/env bash
# compositor.sh — one interface over Hyprland and niri IPC.
#
# Source it from bash scripts:
#     source "$HOME/.config/scripts/lib/compositor.sh"
#     for o in $(list_outputs); do ...; done
# or run it from QML / Python / other shells:
#     ~/.config/scripts/lib/compositor.sh monitors-json
#
# Detection is by the env var each compositor exports to its children, so it
# is correct even when both are installed.

compositor() {
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then echo hyprland
    elif [ -n "${NIRI_SOCKET:-}" ]; then echo niri
    else echo unknown
    fi
}

# Names of enabled outputs, one per line.
list_outputs() {
    case "$(compositor)" in
        hyprland) hyprctl -j monitors 2>/dev/null | jq -r '.[].name' ;;
        # Disabled outputs have no logical geometry
        niri)     niri msg -j outputs 2>/dev/null | jq -r '.[] | select(.logical != null) | .name' ;;
    esac
}

focused_output() {
    case "$(compositor)" in
        hyprland) hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused) | .name' | head -1 ;;
        niri)     niri msg -j focused-output 2>/dev/null | jq -r '.name // empty' ;;
    esac
}

# The output under the pointer. niri has no cursor-position IPC, so there it is
# the focused output (which follows the pointer on click anyway).
pointer_output() {
    case "$(compositor)" in
        hyprland)
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
            ;;
        niri) focused_output ;;
    esac
}

# Enabled outputs as a JSON array in the shape of `hyprctl monitors -j`
# (name, width, height, refreshRate, x, y, scale, focused), whichever
# compositor is running. width/height are the mode's physical pixels.
monitors_json() {
    case "$(compositor)" in
        hyprland) hyprctl -j monitors 2>/dev/null ;;
        niri)
            local focused
            focused=$(focused_output)
            niri msg -j outputs 2>/dev/null | jq --arg f "$focused" '
                [ .[] | select(.logical != null and .current_mode != null)
                  | .modes[.current_mode] as $m
                  | { name, width: $m.width, height: $m.height,
                      refreshRate: ($m.refresh_rate / 1000),
                      x: .logical.x, y: .logical.y, scale: .logical.scale,
                      focused: (.name == $f) } ]'
            ;;
        *) echo '[]' ;;
    esac
}

# Output power / enable state: output_power NAME on|off
# Hyprland blanks via DPMS; niri turns the output off (windows move to the
# remaining outputs until it is turned back on).
output_power() {
    local name="$1" state="$2"
    case "$(compositor)" in
        hyprland) hyprctl dispatch "hl.dsp.dpms({ action = \"$state\", monitor = \"$name\" })" >/dev/null ;;
        niri)     niri msg output "$name" "$state" ;;
    esac
}

# Is the output currently on? Exit status 0 = on.
output_is_on() {
    local name="$1"
    case "$(compositor)" in
        hyprland) [ "$(hyprctl -j monitors 2>/dev/null | jq --arg n "$name" '.[] | select(.name == $n) | .dpmsStatus')" = "true" ] ;;
        niri)     [ "$(niri msg -j outputs 2>/dev/null | jq --arg n "$name" '.[$n].logical != null')" = "true" ] ;;
    esac
}

# niri only matches a mode whose refresh rate is given to three decimals
# ("1920x1200@60.002") and silently falls back to the preferred mode otherwise.
# Map "WxH@RATE" to the output's closest real mode in that exact form.
niri_exact_mode() {
    local name="$1" mode="$2"
    local res="${mode%@*}" rate="${mode#*@}"
    [ "$rate" = "$mode" ] && { printf '%s\n' "$mode"; return; }
    local w="${res%x*}" h="${res#*x}"
    niri msg -j outputs 2>/dev/null | jq -r --arg n "$name" --argjson w "$w" --argjson h "$h" \
        --argjson r "$rate" --arg fallback "$mode" '
        [ .[$n].modes[]? | select(.width == $w and .height == $h) ]
        | if length == 0 then $fallback
          else min_by((.refresh_rate / 1000 - $r) | fabs)
               | "\(.width)x\(.height)@\((.refresh_rate / 1000 * 1000 | round) as $m
                   | "\($m / 1000 | floor).\($m % 1000 | tostring | ("00" + .)[-3:])")"
          end'
}

# Live, non-persistent output configuration:
#   set_output NAME WxH@RATE X Y SCALE
set_output() {
    local name="$1" mode="$2" x="$3" y="$4" scale="$5"
    case "$(compositor)" in
        hyprland)
            hyprctl eval "hl.monitor({ output = '$name', mode = '$mode', position = '${x}x${y}', scale = $scale })" >/dev/null
            ;;
        niri)
            niri msg output "$name" mode "$(niri_exact_mode "$name" "$mode")"
            niri msg output "$name" scale "$scale"
            niri msg output "$name" position set "$x" "$y"
            ;;
    esac
}

focus_workspace() {
    case "$(compositor)" in
        hyprland) hyprctl dispatch "hl.dsp.focus({ workspace = $1 })" >/dev/null ;;
        niri)     niri msg action focus-workspace "$1" ;;
    esac
}

move_window_to_workspace() {
    case "$(compositor)" in
        hyprland) hyprctl dispatch "hl.dsp.window.move({ workspace = $1 })" >/dev/null ;;
        niri)     niri msg action move-window-to-workspace "$1" ;;
    esac
}

# Make the compositor pick up regenerated theme files. niri reloads its config
# on file change by itself, so there is nothing to do there.
reload_compositor() {
    case "$(compositor)" in
        hyprland) hyprctl reload >/dev/null 2>&1 ;;
    esac
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
