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

# Main.qml listens on Quickshell IPC (IpcHandler target "panel").
MAIN_QML_PATH="$HOME/.config/quickshell/Main.qml"

qs_ipc() {
    qs -p "$MAIN_QML_PATH" ipc call panel "$@" 2>/dev/null
}

# Like qs_ipc, but waits up to ~3s for an instance the watchdog below may
# have only just started.
qs_ipc_wait() {
    local _
    for _ in $(seq 15); do
        qs_ipc "$@" && return 0
        sleep 0.2
    done
    echo "qs_manager: quickshell is not answering on IPC" >&2
    return 1
}

send_close() {
    qs_ipc_wait command close >/dev/null
}

# Wire format consumed by Main.qml: "<cmd>[:<arg>]|<anchor>|<monitor>"
emit() {
    qs_ipc_wait command "$(printf '%s|%s|%s' "$1" "$ANCHOR" "$(resolve_monitor)")" >/dev/null
}

# -----------------------------------------------------------------------------
# FAST PATH: WORKSPACE SWITCHING
# -----------------------------------------------------------------------------
if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    WORKSPACE_NUM="$ACTION"
    # Hide any open panel; in the background so it doesn't delay the switch.
    qs_ipc command close >/dev/null &
    
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
# Thumbnail name of the wallpaper that is on screen now, for the picker to
# highlight. Fast on purpose: it runs before the picker opens. Videos play in
# mpvpaper; images are recorded by wallpaper_split.sh.
current_wallpaper_thumb() {
    local cur
    cur=$(pgrep -a mpvpaper 2>/dev/null | grep -o "$SRC_DIR/[^' ]*" | head -n1)
    [ -n "$cur" ] || cur=$(cat "$HOME/.cache/wallpaper/current" 2>/dev/null)
    [ -n "$cur" ] || return 0
    cur=$(basename "$cur")
    if [[ "${cur##*.}" =~ ^(mp4|mkv|mov|webm)$ || "${cur##*.}" =~ ^(MP4|MKV|MOV|WEBM)$ ]]; then
        printf '000_%s' "$cur"
    else
        printf '%s' "$cur"
    fi
}

# Bring the thumbnail cache in line with the wallpaper folder. Runs in the
# background after the picker has opened; the picker's folder model shows new
# thumbnails as they appear.
update_wallpaper_thumbs() {
    mkdir -p "$THUMB_DIR"
    exec 8>"$THUMB_DIR.lock"
    flock -n 8 || return 0 # a previous run is still going
    shopt -s nullglob nocaseglob

    local thumb filename extension img
    for thumb in "$THUMB_DIR"/*; do
        filename=${thumb##*/}
        [ -f "$SRC_DIR/${filename#000_}" ] || rm -f "$thumb"
    done

    for img in "$SRC_DIR"/*.{jpg,jpeg,png,webp,gif,mp4,mkv,mov,webm}; do
        filename=${img##*/}
        extension=${filename##*.}
        if [[ "${extension,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
            thumb="$THUMB_DIR/000_$filename"
            [ -f "$thumb" ] || ffmpeg -y -ss 00:00:05 -i "$img" -vframes 1 -f image2 -q:v 2 "$thumb" >/dev/null 2>&1
        else
            # webp is thumbnailed like any other image; the original is never touched
            thumb="$THUMB_DIR/$filename"
            [ -f "$thumb" ] || magick "$img" -resize x420 -quality 70 "$thumb"
        fi
    done
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
# WATCHDOG: (re)start Quickshell when it does not answer on IPC
# -----------------------------------------------------------------------------
start_quickshell() {
    # Without qt6ct, like autostart.lua: the panels are styled by hand
    QT_QPA_PLATFORMTHEME= quickshell -p "$MAIN_QML_PATH" >/dev/null 2>&1 &
    disown
}

# -----------------------------------------------------------------------------
# IPC ROUTING
# -----------------------------------------------------------------------------
if [[ "$ACTION" == "close" ]]; then
    # Nothing to close if Quickshell is not running, so no waiting here
    qs_ipc command close >/dev/null
    stop_bt_scan
    exit 0
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    # The first IPC call doubles as the liveness check (cheaper than pgrep -f)
    if ! ACTIVE_WIDGET=$(qs_ipc active); then
        start_quickshell
        ACTIVE_WIDGET=$(qs_ipc_wait active)
    fi
    CURRENT_MODE=$(cat "$NETWORK_MODE_FILE" 2>/dev/null)

    if [[ "$TARGET" == "network" ]]; then
        if [[ "$ACTION" == "toggle" && "$ACTIVE_WIDGET" == "network" ]]; then
            if [[ -n "$SUBTARGET" ]]; then
                if [[ "$CURRENT_MODE" == "$SUBTARGET" ]]; then
                    send_close
                    stop_bt_scan
                else
                    echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
                    emit "$TARGET"
                fi
            else
                send_close
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
        send_close
        exit 0
    fi

    if [[ "$TARGET" == "wallpaper" ]]; then
        emit "$TARGET:$(current_wallpaper_thumb)"
        ( update_wallpaper_thumbs ) </dev/null >/dev/null 2>&1 &
        disown
    else
        emit "$TARGET"
    fi
    exit 0
fi
