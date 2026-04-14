#!/usr/bin/env bash

FLAG="$HOME/.cache/wallpaper_initialized"
THEME_APPLY="$HOME/.config/hypr/scripts/theme_apply.sh"
WALLPAPER_SPLIT="$HOME/.config/hypr/scripts/wallpaper_split.sh"
STATE_FILE="$HOME/.cache/current_theme"

# Determine current theme mode
current_theme="coolnight"
[ -f "$STATE_FILE" ] && current_theme=$(cat "$STATE_FILE")

apply_theme() {
    if [ -x "$THEME_APPLY" ]; then
        bash "$THEME_APPLY" "$current_theme"
    fi
}

# If the flag exists, just re-apply the split wallpapers and theme
if [ -f "$FLAG" ]; then
    SPLIT_DIR="$HOME/.config/hypr/scripts/WallpaperSplitter"

    # Wait for awww-daemon to be ready
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        awww query >/dev/null 2>&1 && break
        sleep 0.2
    done

    awww img --outputs DP-2 --resize crop --transition-type none "$SPLIT_DIR/left.png" 2>/dev/null || true
    awww img --outputs DP-1 --resize crop --transition-type none "$SPLIT_DIR/center.png" 2>/dev/null || true
    awww img --outputs DP-3 --resize crop --transition-type none "$SPLIT_DIR/right.png" 2>/dev/null || true

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
    bash "$WALLPAPER_SPLIT" "$file"
fi

mkdir -p "$(dirname "$FLAG")"
touch "$FLAG"
