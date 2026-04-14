#!/usr/bin/env bash
# wallpaper_split.sh — Split a wallpaper for triple monitors, cache, and apply.
# Usage: wallpaper_split.sh <image_path>

set -euo pipefail

SPLIT_DIR="$HOME/.config/hypr/scripts/WallpaperSplitter"
SPLITTER="$SPLIT_DIR/split_wallpaper.py"
CACHE_DIR="$HOME/.cache/wallpaper_splits"
THEME_APPLY="$HOME/.config/hypr/scripts/theme_apply.sh"

src="${1:-}"
[ -z "$src" ] && { echo "Usage: wallpaper_split.sh <image_path>"; exit 1; }

# Expand leading tilde (callers may pass literal ~ — env vars don't expand it)
src="${src/#\~/$HOME}"

# Resolve symlinks so we work with the real file
src=$(readlink -f "$src")
[ -f "$src" ] || { echo "File not found: $src"; exit 1; }

# ── Cache key ──
basename_raw=$(basename "$src")
cache_key="${basename_raw%.*}"
cache_key=$(echo "$cache_key" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_-')
cache_path="$CACHE_DIR/$cache_key"

# ── Split if not cached ──
if [ -f "$cache_path/left.png" ] && [ -f "$cache_path/center.png" ] && [ -f "$cache_path/right.png" ]; then
    echo "Using cached splits: $cache_key"
else
    echo "Splitting: $basename_raw"
    mkdir -p "$cache_path"
    python3 "$SPLITTER" "$src" "$cache_path"
fi

# ── Copy splits to active wallpaper paths ──
cp "$cache_path/left.png"   "$SPLIT_DIR/left.png"
cp "$cache_path/center.png" "$SPLIT_DIR/center.png"
cp "$cache_path/right.png"  "$SPLIT_DIR/right.png"

# ── Apply via awww ──
if ! pgrep -x awww-daemon >/dev/null; then
    awww-daemon >/dev/null 2>&1 &
    disown
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        awww query >/dev/null 2>&1 && break
        sleep 0.1
    done
fi

TRANSITION_ARGS=(--transition-type grow --transition-pos 0.5,0.5 --transition-duration 1.2 --transition-fps 60 --transition-bezier .2,.8,.2,1)
awww img --outputs DP-2 --resize crop "${TRANSITION_ARGS[@]}" "$SPLIT_DIR/left.png"
awww img --outputs DP-1 --resize crop "${TRANSITION_ARGS[@]}" "$SPLIT_DIR/center.png"
awww img --outputs DP-3 --resize crop "${TRANSITION_ARGS[@]}" "$SPLIT_DIR/right.png"

# ── Lock screen background ──
cp "$cache_path/center.png" /tmp/lock_bg.png

# ── Theme: always regenerate from the new wallpaper ──
matugen image "$src" --type scheme-vibrant --prefer saturation >/dev/null 2>&1 || \
matugen image "$src" --type scheme-vibrant --source-color-index 0 >/dev/null 2>&1 || true
bash "$THEME_APPLY" wallpaper 2>/dev/null || true

echo "Done: $basename_raw applied"
