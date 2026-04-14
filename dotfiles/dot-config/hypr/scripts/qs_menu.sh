#!/usr/bin/env bash
# Wofi menu for toggling Quickshell widgets and switching themes.

QS="$HOME/.config/hypr/scripts/qs_manager.sh"
THEME_APPLY="$HOME/.config/hypr/scripts/theme_apply.sh"
THEME_DIR="$HOME/.config/hypr/themes"

# Icons via printf so multi-byte glyphs survive copy/paste.
CAL=$(printf '\xef\x81\xb3')    # U+F073  (FontAwesome calendar)
NET=$(printf '\xf3\xb0\xa4\xa8') # U+F0928 (nf-md-wifi)
VOL=$(printf '\xf3\xb0\x95\xbe') # U+F057E (nf-md-volume_high)
BAT=$(printf '\xf3\xb0\x81\xb9') # U+F0079 (nf-md-battery)
MUS=$(printf '\xf3\xb0\x8e\x86') # U+F0386 (nf-md-music)
MON=$(printf '\xf3\xb0\x8d\xb9') # U+F0379 (nf-md-monitor)
WLP=$(printf '\xef\x80\xbe')    # U+F03E  (FontAwesome image)
FOC=$(printf '\xf3\xb0\x84\x89') # U+F0109 (nf-md-timer)
THM=$(printf '\xf3\xb0\x8d\xb0') # U+F0370 (nf-md-palette)

entries=(
    "${CAL}  Calendar	calendar"
    "${NET}  Network	network"
    "${VOL}  Volume	volume"
    "${BAT}  Battery	battery"
    "${MUS}  Music	music"
    "${MON}  Monitors	monitors"
    "${WLP}  Wallpaper	wallpaper"
    "${FOC}  Focus Time	focustime"
    "${THM}  Theme	_theme"
)

labels=$(printf '%s\n' "${entries[@]}" | cut -f1)

choice=$(printf '%s\n' "$labels" | wofi \
    --dmenu \
    --prompt "Quickshell" \
    --cache-file /dev/null \
    --style "$HOME/.config/wofi/style.css" \
    --width 320 \
    --height 480 \
    --hide-scroll \
    --insensitive) || exit 0

[ -z "$choice" ] && exit 0

# Find the target for the selected label
target=""
for e in "${entries[@]}"; do
    label=$(printf '%s' "$e" | cut -f1)
    t=$(printf '%s' "$e" | cut -f2)
    if [ "$label" = "$choice" ]; then
        target="$t"
        break
    fi
done

[ -z "$target" ] && exit 0

# Theme submenu
if [ "$target" = "_theme" ]; then
    # Build theme list: wallpaper + all JSON files in themes dir
    theme_entries=("Wallpaper (auto)")
    for f in "$THEME_DIR"/*.json; do
        [ -f "$f" ] || continue
        name=$(jq -r '._meta.name // empty' "$f" 2>/dev/null)
        slug=$(basename "$f" .json)
        theme_entries+=("${name:-$slug}")
    done

    theme_choice=$(printf '%s\n' "${theme_entries[@]}" | wofi \
        --dmenu \
        --prompt "Theme" \
        --cache-file /dev/null \
        --style "$HOME/.config/wofi/style.css" \
        --width 320 \
        --height 300 \
        --hide-scroll \
        --insensitive) || exit 0

    [ -z "$theme_choice" ] && exit 0

    if [ "$theme_choice" = "Wallpaper (auto)" ]; then
        # Re-run matugen on current wallpaper, then apply
        if [ -f /tmp/lock_bg.png ]; then
            matugen image /tmp/lock_bg.png --type scheme-vibrant --prefer saturation 2>/dev/null || \
            matugen image /tmp/lock_bg.png --type scheme-vibrant --source-color-index 0 2>/dev/null || true
        fi
        exec bash "$THEME_APPLY" wallpaper
    else
        # Find matching theme slug
        for f in "$THEME_DIR"/*.json; do
            [ -f "$f" ] || continue
            name=$(jq -r '._meta.name // empty' "$f" 2>/dev/null)
            slug=$(basename "$f" .json)
            if [ "$theme_choice" = "$name" ] || [ "$theme_choice" = "$slug" ]; then
                exec bash "$THEME_APPLY" "$slug"
            fi
        done
    fi
    exit 0
fi

# Widget toggle
exec "$QS" toggle "$target"
