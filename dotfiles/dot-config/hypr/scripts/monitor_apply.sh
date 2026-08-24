#!/usr/bin/env bash
# Apply monitor layouts live and persist them to host.lua.
#
# Usage: monitor_apply.sh "NAME,WxH@RATE,XxY,SCALE" [ ... ]
#
# Called by the quickshell monitor panel. Everything in host.lua above the
# marker line is preserved; the monitor block below it is regenerated.

set -euo pipefail

HOST_LUA="$HOME/.config/hypr/host.lua"
MARKER='-- >>> monitors (rewritten by scripts/monitor_apply.sh — edit above this line)'

[ "$#" -gt 0 ] || { echo "usage: $0 \"NAME,WxH@RATE,XxY,SCALE\" ..." >&2; exit 1; }

lua_lines=()

for spec in "$@"; do
    IFS=',' read -r name mode pos scale <<< "$spec"
    [ -n "${scale:-}" ] || scale=1
    hyprctl eval "hl.monitor({ output = '$name', mode = '$mode', position = '$pos', scale = $scale })" >/dev/null
    lua_lines+=("hl.monitor({ output = \"$name\", mode = \"$mode\", position = \"$pos\", scale = $scale })")
done

# Rebuild host.lua: preamble (up to and excluding the marker) + marker + monitors.
tmp=$(mktemp)
if [ -f "$HOST_LUA" ] && grep -qF -- "$MARKER" "$HOST_LUA"; then
    sed -e "/$(printf '%s' "$MARKER" | sed 's/[][\.*^$/]/\\&/g')/,\$d" "$HOST_LUA" > "$tmp"
else
    [ -f "$HOST_LUA" ] && cat "$HOST_LUA" >> "$tmp"
    printf '\n' >> "$tmp"
fi

printf '%s\n' "$MARKER" >> "$tmp"
printf '%s\n' "${lua_lines[@]}" >> "$tmp"

mv "$tmp" "$HOST_LUA"
