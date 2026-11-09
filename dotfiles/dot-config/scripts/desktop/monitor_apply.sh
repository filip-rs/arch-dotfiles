#!/usr/bin/env bash
# Apply monitor layouts live and persist them for the running compositor.
#
# Usage: monitor_apply.sh "NAME,WxH@RATE,XxY,SCALE" [ ... ]
#
# Called by the quickshell monitor panel. Layouts are persisted per machine in
# the untracked ~/.config/hypr/host.lua. Everything above the marker line is
# preserved; the monitor block below it is regenerated.

set -euo pipefail

source "$HOME/.config/scripts/lib/compositor.sh"

[ "$#" -gt 0 ] || { echo "usage: $0 \"NAME,WxH@RATE,XxY,SCALE\" ..." >&2; exit 1; }

[ "$(compositor)" = hyprland ] || { echo "Hyprland is not running" >&2; exit 1; }
HOST_FILE="$HOME/.config/hypr/host.lua"
MARKER='-- >>> monitors (rewritten by scripts/desktop/monitor_apply.sh — edit above this line)'

host_lines=()

for spec in "$@"; do
    IFS=',' read -r name mode pos scale <<< "$spec"
    [ -n "${scale:-}" ] || scale=1
    x="${pos%%x*}"
    y="${pos##*x}"
    set_output "$name" "$mode" "$x" "$y" "$scale"

    host_lines+=("hl.monitor({ output = \"$name\", mode = \"$mode\", position = \"$pos\", scale = $scale })")
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
