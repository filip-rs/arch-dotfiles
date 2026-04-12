#!/usr/bin/env bash

FLAG="$HOME/.cache/wallpaper_initialized"
THEME_APPLY="$HOME/.config/hypr/scripts/theme_apply.sh"
STATE_FILE="$HOME/.cache/current_theme"

# Determine current theme mode
current_theme="coolnight"
[ -f "$STATE_FILE" ] && current_theme=$(cat "$STATE_FILE")

apply_theme() {
    if [ -x "$THEME_APPLY" ]; then
        bash "$THEME_APPLY" "$current_theme"
    fi
}

# If the flag exists, just re-apply colors and exit
if [ -f "$FLAG" ]; then
    if [ "$current_theme" = "wallpaper" ] && [ -f "/tmp/lock_bg.png" ]; then
        matugen image "/tmp/lock_bg.png" --source-color-index 0
    fi
    apply_theme
    exit 0
fi

# First boot: pick a random wallpaper
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

sleep 0.5

file=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null | shuf -n 1)

if [ -n "$file" ]; then
    cp "$file" /tmp/lock_bg.png

    swww img "$file" --transition-type any --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1 &

    if [ "$current_theme" = "wallpaper" ]; then
        matugen image "$file" --source-color-index 0
    fi
    apply_theme
fi

mkdir -p "$(dirname "$FLAG")"
touch "$FLAG"
