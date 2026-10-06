#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# CONSTANTS & ARGUMENTS
# -----------------------------------------------------------------------------
QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOME/.config/scripts/lib/compositor.sh"
# Shared with quickshell/network/bluetooth_panel_logic.sh
BT_PID_FILE="${XDG_RUNTIME_DIR:-$HOME/.cache}/quickshell_network_cache/bt_scan_pid"
BT_SCAN_SECONDS=90
SRC_DIR="${WALLPAPER_DIR:-${srcdir:-$HOME/Pictures/Wallpapers}}"
# Expand leading ~ (hyprland env vars don't expand tilde)
SRC_DIR="${SRC_DIR/#\~/$HOME}"
THUMB_DIR="$HOME/.cache/wallpaper_picker/thumbs"

# User-specific cache directory matching the QML logic
QS_NETWORK_CACHE="${XDG_RUNTIME_DIR:-$HOME/.cache}/qs_network"
mkdir -p "$QS_NETWORK_CACHE"

IPC_FILE="/tmp/qs_widget_state"
NETWORK_MODE_FILE="$QS_NETWORK_CACHE/mode"

# Flags may appear anywhere; positional args keep their meaning.
#   --anchor=left|center|right   which side of the bar the caller sits on
#   --monitor=NAME               which output to open the panel on
ANCHOR=""
MONITOR=""
POSITIONAL=()
for _arg in "$@"; do
    case "$_arg" in
        --anchor=*)  ANCHOR="${_arg#*=}" ;;
        --monitor=*) MONITOR="${_arg#*=}" ;;
        *)           POSITIONAL+=("$_arg") ;;
    esac
done
set -- "${POSITIONAL[@]}"

ACTION="${1:-}"
TARGET="${2:-}"
SUBTARGET="${3:-}"

# The output the panel should appear on: an explicit --monitor, else the one
# under the pointer (bar clicks are mouse-driven), else the focused one.
resolve_monitor() {
    if [ -n "$MONITOR" ]; then
        printf '%s' "$MONITOR"
        return
    fi

    printf '%s' "$(pointer_output)"
}

# Wire format consumed by Main.qml: "<cmd>[:<arg>]|<anchor>|<monitor>"
emit() {
    printf '%s|%s|%s\n' "$1" "$ANCHOR" "$(resolve_monitor)" > "$IPC_FILE"
}

# -----------------------------------------------------------------------------
# FAST PATH: WORKSPACE SWITCHING
# -----------------------------------------------------------------------------
if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    WORKSPACE_NUM="$ACTION"
    echo "close" > "$IPC_FILE" # Tell QML to hide the widget natively
    
    if [[ "$2" == "move" ]]; then
        move_window_to_workspace "$WORKSPACE_NUM" >/dev/null 2>&1
    else
        focus_workspace "$WORKSPACE_NUM" >/dev/null 2>&1
    fi
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
        SPLIT_DIR="$HOME/.config/scripts/desktop/WallpaperSplitter"
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

# The scan runs in its own process group with a hard time limit: the panel can
# also be closed from QML (Escape, click-away) without going through here, and
# an unbounded scan would keep the adapter discovering forever.
stop_bt_scan() {
    local pgid
    pgid=$(cat "$BT_PID_FILE" 2>/dev/null)
    # Only signal the group if the leader is still our timeout (PIDs get reused)
    if [ -n "$pgid" ] && [ "$(ps -o comm= -p "$pgid" 2>/dev/null)" = "timeout" ]; then
        kill -- "-$pgid" 2>/dev/null
    fi
    rm -f "$BT_PID_FILE"
}

start_bt_scan() {
    stop_bt_scan
    mkdir -p "$(dirname "$BT_PID_FILE")"
    setsid timeout $((BT_SCAN_SECONDS + 5)) bluetoothctl --timeout "$BT_SCAN_SECONDS" scan on >/dev/null 2>&1 &
    echo $! > "$BT_PID_FILE"
}

handle_network_prep() {
    start_bt_scan
    (nmcli device wifi rescan) &
}

# -----------------------------------------------------------------------------
# ZOMBIE WATCHDOG
# -----------------------------------------------------------------------------
MAIN_QML_PATH="$HOME/.config/quickshell/Main.qml"

if ! pgrep -f "quickshell.*Main\.qml" >/dev/null; then
    quickshell -p "$MAIN_QML_PATH" >/dev/null 2>&1 &
    disown
fi

# TopBar intentionally disabled — waybar is in use instead.
# The widget overlay (Main.qml) still works via keybinds below.

# -----------------------------------------------------------------------------
# IPC ROUTING
# -----------------------------------------------------------------------------
if [[ "$ACTION" == "close" ]]; then
    echo "close" > "$IPC_FILE"
    stop_bt_scan
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
                    stop_bt_scan
                else
                    echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
                    emit "$TARGET"
                fi
            else
                echo "close" > "$IPC_FILE"
                stop_bt_scan
            fi
        else
            handle_network_prep
            [[ -n "$SUBTARGET" ]] && echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
            emit "$TARGET"
        fi
        exit 0
    fi

    # Any other panel replaces the network one, so its scan can go too
    stop_bt_scan

    if [[ "$ACTION" == "toggle" && "$ACTIVE_WIDGET" == "$TARGET" ]]; then
        echo "close" > "$IPC_FILE"
        exit 0
    fi

    if [[ "$TARGET" == "wallpaper" ]]; then
        handle_wallpaper_prep
        emit "$TARGET:$WALLPAPER_THUMB"
    else
        emit "$TARGET"
    fi
    exit 0
fi
