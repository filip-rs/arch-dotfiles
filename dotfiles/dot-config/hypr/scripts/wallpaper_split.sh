#!/usr/bin/env bash
# wallpaper_split.sh — Apply a wallpaper across connected outputs.
#
# Triple-monitor mode (DP-2/DP-1/DP-3 all present AND image width >= TRIPLE_MIN_WIDTH):
#   split into left/center/right; unknown outputs fall back to center.
# Otherwise: produce only a center image and apply it to every connected output.
#
# Usage: wallpaper_split.sh <image_path>

set -euo pipefail

SPLIT_DIR="$HOME/.config/hypr/scripts/WallpaperSplitter"
SPLITTER="$SPLIT_DIR/split_wallpaper.py"
CACHE_DIR="$HOME/.cache/wallpaper_splits"
THEME_APPLY="$HOME/.config/hypr/scripts/theme_apply.sh"

LEFT_OUTPUT="DP-2"
CENTER_OUTPUT="DP-1"
RIGHT_OUTPUT="DP-3"
TRIPLE_MIN_WIDTH=7680

src="${1:-}"
[ -z "$src" ] && { echo "Usage: wallpaper_split.sh <image_path>"; exit 1; }

src="${src/#\~/$HOME}"
src=$(readlink -f "$src")
[ -f "$src" ] || { echo "File not found: $src"; exit 1; }

# ── Detect connected outputs ──
mapfile -t OUTPUTS < <(hyprctl -j monitors 2>/dev/null | jq -r '.[].name')
if [ "${#OUTPUTS[@]}" -eq 0 ]; then
    echo "No outputs reported by hyprctl; aborting"; exit 1
fi

# ── Measure image width ──
img_width=$(python3 -c 'import sys; from PIL import Image; print(Image.open(sys.argv[1]).size[0])' "$src")

# ── Decide mode ──
have_left=false; have_center=false; have_right=false
for o in "${OUTPUTS[@]}"; do
    [ "$o" = "$LEFT_OUTPUT" ]   && have_left=true
    [ "$o" = "$CENTER_OUTPUT" ] && have_center=true
    [ "$o" = "$RIGHT_OUTPUT" ]  && have_right=true
done

triple=false
if $have_left && $have_center && $have_right && [ "$img_width" -ge "$TRIPLE_MIN_WIDTH" ]; then
    triple=true
fi

if $triple; then
    mode_tag="triple"
    echo "Mode: triple (image ${img_width}px ≥ ${TRIPLE_MIN_WIDTH}px, DP-2/DP-1/DP-3 present)"
else
    mode_tag="center"
    reason="image ${img_width}px < ${TRIPLE_MIN_WIDTH}px"
    $have_left && $have_center && $have_right || reason="missing triple outputs"
    echo "Mode: center-only ($reason)"
fi

# ── Cache key ──
basename_raw=$(basename "$src")
cache_key="${basename_raw%.*}"
cache_key=$(echo "$cache_key" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_-')
cache_path="$CACHE_DIR/${cache_key}__${mode_tag}"

# ── Split if not cached ──
if $triple; then
    if [ -f "$cache_path/left.png" ] && [ -f "$cache_path/center.png" ] && [ -f "$cache_path/right.png" ]; then
        echo "Using cached splits: $cache_key ($mode_tag)"
    else
        echo "Splitting (triple): $basename_raw"
        mkdir -p "$cache_path"
        python3 "$SPLITTER" "$src" "$cache_path"
    fi
else
    if [ -f "$cache_path/center.png" ]; then
        echo "Using cached center: $cache_key ($mode_tag)"
    else
        echo "Rendering center: $basename_raw"
        mkdir -p "$cache_path"
        python3 "$SPLITTER" "$src" "$cache_path" --center-only
    fi
fi

# ── Copy to active wallpaper paths ──
cp "$cache_path/center.png" "$SPLIT_DIR/center.png"
if $triple; then
    cp "$cache_path/left.png"  "$SPLIT_DIR/left.png"
    cp "$cache_path/right.png" "$SPLIT_DIR/right.png"
fi

# ── Ensure awww daemon ──
if ! pgrep -x awww-daemon >/dev/null; then
    awww-daemon >/dev/null 2>&1 &
    disown
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        awww query >/dev/null 2>&1 && break
        sleep 0.1
    done
fi

TRANSITION_ARGS=(--transition-type grow --transition-pos 0.5,0.5 --transition-duration 1.2 --transition-fps 60 --transition-bezier .2,.8,.2,1)

# ── Apply per output ──
for o in "${OUTPUTS[@]}"; do
    if $triple; then
        case "$o" in
            "$LEFT_OUTPUT")  img="$SPLIT_DIR/left.png" ;;
            "$RIGHT_OUTPUT") img="$SPLIT_DIR/right.png" ;;
            *)               img="$SPLIT_DIR/center.png" ;;
        esac
    else
        img="$SPLIT_DIR/center.png"
    fi
    awww img --outputs "$o" --resize crop "${TRANSITION_ARGS[@]}" "$img"
done

# ── Lock screen background ──
cp "$cache_path/center.png" /tmp/lock_bg.png

# ── Theme: always regenerate from the new wallpaper ──
STATE_FILE="$HOME/.cache/current_theme"
current_theme=""
[ -f "$STATE_FILE" ] && current_theme=$(cat "$STATE_FILE")

MATUGEN_MODE_FLAG=()
APPLY_MODE="wallpaper"
if [ "$current_theme" = "wallpaper-light" ]; then
    MATUGEN_MODE_FLAG=(-m light --contrast -0.5)
    APPLY_MODE="wallpaper-light"
fi

if [ ! -f "$HOME/.config/matugen/config.toml" ]; then
    echo "warning: ~/.config/matugen/config.toml missing — theme will not update. Run: cd ~/Services/arch-dotfiles/dotfiles && stow . --dotfiles -t \$HOME" >&2
else
    matugen image "$src" --type scheme-content --prefer saturation "${MATUGEN_MODE_FLAG[@]}" >/dev/null 2>&1 || \
        echo "warning: matugen failed on $src" >&2
fi
bash "$THEME_APPLY" "$APPLY_MODE" 2>/dev/null || true

echo "Done: $basename_raw applied ($mode_tag)"
