#!/usr/bin/env bash
# Called after matugen generates colors from a wallpaper.
# Delegates all color application to theme_apply.sh (wallpaper mode).

THEME_APPLY="$HOME/.config/hypr/scripts/theme_apply.sh"

if [ -x "$THEME_APPLY" ]; then
    bash "$THEME_APPLY" wallpaper
else
    echo "Error: theme_apply.sh not found at $THEME_APPLY"
fi
