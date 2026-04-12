#!/usr/bin/env bash
# Wofi menu for toggling Quickshell widgets via qs_manager.sh

QS="$HOME/.config/hypr/scripts/qs_manager.sh"

# Icons taken from quickshell/guide/GuidePopup.qml for consistency.
# Built via printf so multi-byte glyphs survive any copy/paste mishaps.
CAL=$(printf '\xef\x81\xb3')    # U+F073  (FontAwesome calendar)
NET=$(printf '\xf3\xb0\xa4\xa8') # U+F0928 (nf-md-wifi)
VOL=$(printf '\xf3\xb0\x95\xbe') # U+F057E (nf-md-volume_high)
BAT=$(printf '\xf3\xb0\x81\xb9') # U+F0079 (nf-md-battery)
MUS=$(printf '\xf3\xb0\x8e\x86') # U+F0386 (nf-md-music)
MON=$(printf '\xf3\xb0\x8d\xb9') # U+F0379 (nf-md-monitor)
WLP=$(printf '\xef\x80\xbe')    # U+F03E  (FontAwesome image)
FOC=$(printf '\xf3\xb0\x84\x89') # U+F0109 (nf-md-timer)

entries=(
    "${CAL}  Calendar	calendar"
    "${NET}  Network	network"
    "${VOL}  Volume	volume"
    "${BAT}  Battery	battery"
    "${MUS}  Music	music"
    "${MON}  Monitors	monitors"
    "${WLP}  Wallpaper	wallpaper"
    "${FOC}  Focus Time	focustime"
)

labels=$(printf '%s\n' "${entries[@]}" | cut -f1)

choice=$(printf '%s\n' "$labels" | wofi \
    --dmenu \
    --prompt "Widget" \
    --cache-file /dev/null \
    --style "$HOME/.config/wofi/style.css" \
    --width 320 \
    --height 430 \
    --hide-scroll \
    --insensitive) || exit 0

[ -z "$choice" ] && exit 0

for e in "${entries[@]}"; do
    label=$(printf '%s' "$e" | cut -f1)
    target=$(printf '%s' "$e" | cut -f2)
    if [ "$label" = "$choice" ]; then
        exec "$QS" toggle "$target"
    fi
done
