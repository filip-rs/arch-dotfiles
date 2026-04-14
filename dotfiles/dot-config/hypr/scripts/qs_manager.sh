#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# CONSTANTS & ARGUMENTS
# -----------------------------------------------------------------------------
QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BT_PID_FILE="$HOME/.cache/bt_scan_pid"
BT_SCAN_LOG="$HOME/.cache/bt_scan.log"
SRC_DIR="${WALLPAPER_DIR:-${srcdir:-$HOME/Pictures/Wallpapers}}"
# Expand leading ~ (hyprland env vars don't expand tilde)
SRC_DIR="${SRC_DIR/#\~/$HOME}"
THUMB_DIR="$HOME/.cache/wallpaper_picker/thumbs"

# User-specific cache directory matching the QML logic
QS_NETWORK_CACHE="${XDG_RUNTIME_DIR:-$HOME/.cache}/qs_network"
mkdir -p "$QS_NETWORK_CACHE"

IPC_FILE="/tmp/qs_widget_state"
NETWORK_MODE_FILE="$QS_NETWORK_CACHE/mode"

ACTION="$1"
TARGET="$2"
SUBTARGET="$3"

# -----------------------------------------------------------------------------
# FAST PATH: WORKSPACE SWITCHING
# -----------------------------------------------------------------------------
if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    WORKSPACE_NUM="$ACTION"
    echo "close" > "$IPC_FILE" # Tell QML to hide the widget natively
    
    CMD="workspace $WORKSPACE_NUM"
    [[ "$2" == "move" ]] && CMD="movetoworkspace $WORKSPACE_NUM"
    hyprctl --batch "dispatch $CMD" >/dev/null 2>&1
    exit 0
fi

# -----------------------------------------------------------------------------
# PREP FUNCTIONS
# -----------------------------------------------------------------------------
handle_wallpaper_prep() {
    mkdir -p "$THUMB_DIR"

    # Clean stale thumbnails
    for thumb in "$THUMB_DIR"/*; do
        [ -e "$thumb" ] || continue
        filename=$(basename "$thumb")
        clean_name="${filename#000_}"
        if [ ! -f "$SRC_DIR/$clean_name" ]; then rm -f "$thumb"; fi
    done

    for img in "$SRC_DIR"/*.{jpg,jpeg,png,webp,gif,mp4,mkv,mov,webm}; do
        [ -e "$img" ] || continue
        filename=$(basename "$img")
        extension="${filename##*.}"

        if [[ "${extension,,}" == "webp" ]]; then
            new_img="${img%.*}.jpg"
            magick "$img" "$new_img"
            rm -f "$img"
            img="$new_img"
            filename=$(basename "$img")
            extension="jpg"
        fi

        if [[ "${extension,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
            thumb="$THUMB_DIR/000_$filename"
            [ -f "$THUMB_DIR/$filename" ] && rm -f "$THUMB_DIR/$filename"
            if [ ! -f "$thumb" ]; then
                 ffmpeg -y -ss 00:00:05 -i "$img" -vframes 1 -f image2 -q:v 2 "$thumb" > /dev/null 2>&1
            fi
        else
            thumb="$THUMB_DIR/$filename"
            if [ ! -f "$thumb" ]; then
                magick "$img" -resize x420 -quality 70 "$thumb"
            fi
        fi
    done

    TARGET_THUMB=""
    CURRENT_SRC=""

    if pgrep -a "mpvpaper" > /dev/null; then
        CURRENT_SRC=$(pgrep -a mpvpaper | grep -o "$SRC_DIR/[^' ]*" | head -n1)
        CURRENT_SRC=$(basename "$CURRENT_SRC")
    fi

    if [ -z "$CURRENT_SRC" ]; then
        # Derive current wallpaper name from the cached split used as center.png
        SPLIT_DIR="$HOME/.config/hypr/scripts/WallpaperSplitter"
        CENTER="$SPLIT_DIR/center.png"
        if [ -f "$CENTER" ]; then
            CENTER_SUM=$(md5sum "$CENTER" 2>/dev/null | awk '{print $1}')
            for cache in "$HOME/.cache/wallpaper_splits"/*/center.png; do
                [ -e "$cache" ] || continue
                if [ "$(md5sum "$cache" | awk '{print $1}')" = "$CENTER_SUM" ]; then
                    key=$(basename "$(dirname "$cache")")
                    for candidate in "$SRC_DIR"/*; do
                        [ -e "$candidate" ] || continue
                        cand_base=$(basename "$candidate")
                        cand_key="${cand_base%.*}"
                        cand_key=$(echo "$cand_key" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_-')
                        if [ "$cand_key" = "$key" ]; then
                            CURRENT_SRC="$cand_base"
                            break
                        fi
                    done
                    break
                fi
            done
        fi
    fi

    if [ -n "$CURRENT_SRC" ]; then
        EXT="${CURRENT_SRC##*.}"
        if [[ "${EXT,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
            TARGET_THUMB="000_$CURRENT_SRC"
        else
            TARGET_THUMB="$CURRENT_SRC"
        fi
    fi
    
    export WALLPAPER_THUMB="$TARGET_THUMB"
}

handle_network_prep() {
    echo "" > "$BT_SCAN_LOG"
    { echo "scan on"; sleep infinity; } | stdbuf -oL bluetoothctl > "$BT_SCAN_LOG" 2>&1 &
    echo $! > "$BT_PID_FILE"
    (nmcli device wifi rescan) &
}

# -----------------------------------------------------------------------------
# ZOMBIE WATCHDOG
# -----------------------------------------------------------------------------
MAIN_QML_PATH="$HOME/.config/hypr/scripts/quickshell/Main.qml"

if ! pgrep -f "quickshell.*Main\.qml" >/dev/null; then
    quickshell -p "$MAIN_QML_PATH" >/dev/null 2>&1 &
    disown
fi

# TopBar intentionally disabled — waybar is in use instead.
# The widget overlay (Main.qml) still works via keybinds below.

# -----------------------------------------------------------------------------
# IPC ROUTING (No hyprctl focus/move commands needed!)
# -----------------------------------------------------------------------------
if [[ "$ACTION" == "close" ]]; then
    echo "close" > "$IPC_FILE"
    if [[ "$TARGET" == "network" || "$TARGET" == "all" || -z "$TARGET" ]]; then
        if [ -f "$BT_PID_FILE" ]; then
            kill $(cat "$BT_PID_FILE") 2>/dev/null
            rm -f "$BT_PID_FILE"
        fi
        (bluetoothctl scan off > /dev/null 2>&1) &
    fi
    exit 0
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    ACTIVE_WIDGET=$(cat /tmp/qs_active_widget 2>/dev/null)
    CURRENT_MODE=$(cat "$NETWORK_MODE_FILE" 2>/dev/null)

    if [[ "$TARGET" == "network" ]]; then
        if [[ "$ACTION" == "toggle" && "$ACTIVE_WIDGET" == "network" ]]; then
            if [[ -n "$SUBTARGET" ]]; then
                if [[ "$CURRENT_MODE" == "$SUBTARGET" ]]; then
                    echo "close" > "$IPC_FILE"
                else
                    echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
                    echo "$TARGET" > "$IPC_FILE"
                fi
            else
                echo "close" > "$IPC_FILE"
            fi
        else
            handle_network_prep
            [[ -n "$SUBTARGET" ]] && echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
            echo "$TARGET" > "$IPC_FILE"
        fi
        exit 0
    fi

    if [[ "$ACTION" == "toggle" && "$ACTIVE_WIDGET" == "$TARGET" ]]; then
        echo "close" > "$IPC_FILE"
        exit 0
    fi

    if [[ "$TARGET" == "wallpaper" ]]; then
        handle_wallpaper_prep
        echo "$TARGET:$WALLPAPER_THUMB" > "$IPC_FILE"
    else
        echo "$TARGET" > "$IPC_FILE"
    fi
    exit 0
fi
