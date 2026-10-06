#!/usr/bin/env bash

FLAG="$HOME/.cache/wallpaper_initialized"
THEME_APPLY="$HOME/.config/scripts/desktop/theme_apply.sh"
WALLPAPER_SPLIT="$HOME/.config/scripts/desktop/wallpaper_split.sh"
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
    SPLIT_DIR="$HOME/.config/scripts/desktop/WallpaperSplitter"

    # Wait for awww-daemon to be ready
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        awww query >/dev/null 2>&1 && break
        sleep 0.2
    done

    # Same mapping as wallpaper_split.sh: desktop sides get their split,
    # everything else (incl. the laptop panel) gets the center image.
    source "$HOME/.config/scripts/lib/compositor.sh"
    for o in $(list_outputs); do
        img="$SPLIT_DIR/center.png"
        [ "$o" = "DP-2" ] && [ -f "$SPLIT_DIR/left.png" ]  && img="$SPLIT_DIR/left.png"
        [ "$o" = "DP-3" ] && [ -f "$SPLIT_DIR/right.png" ] && img="$SPLIT_DIR/right.png"
        awww img --outputs "$o" --resize crop --transition-type none "$img" 2>/dev/null || true
    done

    if [ "$current_theme" = "wallpaper" ] && [ -f "/tmp/lock_bg.png" ]; then
        matugen image "/tmp/lock_bg.png" --source-color-index 0
    elif [ "$current_theme" = "wallpaper-light" ] && [ -f "/tmp/lock_bg.png" ]; then
        matugen image "/tmp/lock_bg.png" --source-color-index 0 -m light --contrast -0.5
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
