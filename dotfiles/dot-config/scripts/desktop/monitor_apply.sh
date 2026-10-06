#!/usr/bin/env bash
# Apply monitor layouts live and persist them for the running compositor.
#
# Usage: monitor_apply.sh "NAME,WxH@RATE,XxY,SCALE" [ ... ]
#
# Called by the quickshell monitor panel. Layouts are persisted per machine in
# an untracked file: ~/.config/hypr/host.lua on Hyprland, ~/.config/niri/host.kdl
# on niri (included optionally from config.kdl). Everything above the marker
# line is preserved; the monitor block below it is regenerated.

set -euo pipefail

source "$HOME/.config/scripts/lib/compositor.sh"

[ "$#" -gt 0 ] || { echo "usage: $0 \"NAME,WxH@RATE,XxY,SCALE\" ..." >&2; exit 1; }

case "$(compositor)" in
    hyprland)
        HOST_FILE="$HOME/.config/hypr/host.lua"
        MARKER='-- >>> monitors (rewritten by scripts/desktop/monitor_apply.sh — edit above this line)'
        ;;
    niri)
        HOST_FILE="$HOME/.config/niri/host.kdl"
        MARKER='// >>> outputs (rewritten by scripts/desktop/monitor_apply.sh — edit above this line)'
        ;;
    *) echo "No supported compositor running" >&2; exit 1 ;;
esac

host_lines=()

for spec in "$@"; do
    IFS=',' read -r name mode pos scale <<< "$spec"
    [ -n "${scale:-}" ] || scale=1
    x="${pos%%x*}"
    y="${pos##*x}"
    set_output "$name" "$mode" "$x" "$y" "$scale"

    case "$(compositor)" in
        hyprland)
            host_lines+=("hl.monitor({ output = \"$name\", mode = \"$mode\", position = \"$pos\", scale = $scale })")
            ;;
        niri)
            host_lines+=("output \"$name\" {" "    mode \"$(niri_exact_mode "$name" "$mode")\"" "    scale $scale" "    position x=$x y=$y" "}")
            ;;
    esac
done

# Rebuild the host file: preamble (up to and excluding the marker) + marker + monitors.
# Older host.lua files carry the marker with the pre-move path; match that too.
tmp=$(mktemp)
old_marker="${MARKER/scripts\/desktop\//scripts/}"
if [ -f "$HOST_FILE" ] && grep -qF -- "$MARKER" "$HOST_FILE"; then
    sed -e "/$(printf '%s' "$MARKER" | sed 's/[][\.*^$/]/\\&/g')/,\$d" "$HOST_FILE" > "$tmp"
elif [ -f "$HOST_FILE" ] && grep -qF -- "$old_marker" "$HOST_FILE"; then
    sed -e "/$(printf '%s' "$old_marker" | sed 's/[][\.*^$/]/\\&/g')/,\$d" "$HOST_FILE" > "$tmp"
else
    [ -f "$HOST_FILE" ] && cat "$HOST_FILE" >> "$tmp"
    printf '\n' >> "$tmp"
fi

printf '%s\n' "$MARKER" >> "$tmp"
printf '%s\n' "${host_lines[@]}" >> "$tmp"

mv "$tmp" "$HOST_FILE"
