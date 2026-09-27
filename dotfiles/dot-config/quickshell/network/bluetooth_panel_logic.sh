#!/usr/bin/env bash

# --- CONFIGURATION ---
# Set to 'true' to hide unpaired devices that only broadcast a MAC address (filters out public BLE spam).
# Set to 'false' if you are trying to pair a stubborn new device that won't show its name.
STRICT_SPAM_FILTER=true
# ---------------------

# Use XDG_RUNTIME_DIR if available for ram-backed speed, else fallback to ~/.cache
CACHE_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/quickshell_network_cache"
mkdir -p "$CACHE_DIR"
PID_FILE="$CACHE_DIR/bt_scan_pid"

# Last noise-control mode we asked librepods for. librepods-ctl is write-only
# (it writes to the /tmp/app_server QLocalSocket and never reads a reply), and
# the daemon registers no D-Bus name to query, so the current mode is tracked
# here.
ANC_STATE_FILE="$CACHE_DIR/anc_mode"

is_airpods() {
    local mac="$1"
    local name="${2,,}"
    [[ "$name" == *"airpods"* || "$name" == *"pods"* ]] && return 0
    # Apple vendor ID 0x004C in the Modalias.
    bluetoothctl info "$mac" 2>/dev/null | grep -qi 'Modalias: bluetooth:v004C' && return 0
    return 1
}

anc_get() {
    cat "$ANC_STATE_FILE" 2>/dev/null || true
}

anc_set() {
    local mode="$1"
    case "$mode" in
        off|anc|transparency|adaptive) ;;
        *) echo "unknown noise mode: $mode" >&2; return 1 ;;
    esac

    if ! command -v librepods-ctl >/dev/null 2>&1; then
        notify-send "AirPods" "librepods-ctl is not installed" 2>/dev/null
        return 1
    fi

    # The CLI only talks to a running daemon.
    if ! pgrep -x librepods >/dev/null 2>&1; then
        setsid librepods --hide >/dev/null 2>&1 &
        disown 2>/dev/null || true
        sleep 1.5
    fi

    if librepods-ctl "noise:$mode" >/dev/null 2>&1; then
        echo "$mode" > "$ANC_STATE_FILE"
    else
        notify-send "AirPods" "Could not reach librepods" 2>/dev/null
        return 1
    fi
}

get_icon() {
    local type="${1,,}"
    local name="${2,,}"
    if [[ "$type" == *"headset"* || "$type" == *"headphone"* || "$name" == *"headphone"* || "$name" == *"buds"* || "$name" == *"pods"* ]]; then echo "🎧"
    elif [[ "$type" == *"audio"* || "$type" == *"speaker"* || "$type" == *"card"* || "$name" == *"speaker"* ]]; then echo "蓼"
    elif [[ "$type" == *"phone"* || "$name" == *"phone"* || "$name" == *"iphone"* || "$name" == *"android"* ]]; then echo ""
    elif [[ "$type" == *"mouse"* || "$name" == *"mouse"* ]]; then echo ""
    elif [[ "$type" == *"keyboard"* || "$name" == *"keyboard"* ]]; then echo ""
    elif [[ "$type" == *"controller"* || "$name" == *"controller"* ]]; then echo ""
    else echo ""
    fi
}

get_audio_profile() {
    local mac="$1"
    local mac_us="${mac//:/_}"
    
    local active=$(pactl list cards 2>/dev/null | awk -v mac="$mac_us" '
        tolower($0) ~ "name:.*"tolower(mac) { found=1 }
        found && tolower($0) ~ "active profile:" { 
            sub(/.*Active Profile: /, ""); print; exit 
        }
        found && /^$/ { exit }
    ')
    
    if [[ -z "$active" || "$active" == "off" ]]; then echo "None"; return; fi
    
    if [[ "$active" == *"a2dp"* ]]; then echo "Hi-Fi (A2DP)"; return; fi
    if [[ "$active" == *"headset"* || "$active" == *"hfp"* ]]; then echo "Headset (HFP)"; return; fi
    
    echo "Connected"
}

get_status() {
    power="off"
    if bluetoothctl show | grep -q "Powered: yes"; then power="on"; fi

    connected_json="[]"
    devices_json="[]"

    if [ "$power" == "on" ]; then
        paired_macs=$(bluetoothctl devices Paired)
        mapfile -t devices < <(bluetoothctl devices)
        mapfile -t connected_info_lines < <(bluetoothctl devices Connected)
        
        connected_macs=""
        connected_list_objs=()
        devices_list_objs=()

        # 1. PROCESS CONNECTED DEVICES (Always shown)
        for c_line in "${connected_info_lines[@]}"; do
            [ -z "$c_line" ] && continue
            rest="${c_line#Device }"
            mac="${rest%% *}"
            name="${rest#* }"
            connected_macs+="$mac "
            
            CACHE_FILE="$CACHE_DIR/bt_stat_${mac//:/_}"

            if [ -f "$CACHE_FILE" ]; then
                source "$CACHE_FILE"
            else
                info=$(bluetoothctl info "$mac")
                icon_type=$(echo "$info" | awk -F': ' '/Icon:/ {print $2}')
                icon=$(get_icon "$icon_type" "$name")
                profile=$(get_audio_profile "$mac")
                
                echo "CACHE_NAME=\"${name//\"/\\\"}\"" > "$CACHE_FILE"
                echo "CACHE_ICON=\"${icon//\"/\\\"}\"" >> "$CACHE_FILE"
                echo "CACHE_PROFILE=\"${profile//\"/\\\"}\"" >> "$CACHE_FILE"
                
                CACHE_NAME="${name//\"/\\\"}"
                CACHE_ICON="${icon//\"/\\\"}"
                CACHE_PROFILE="${profile//\"/\\\"}"
            fi
            
            bat=$(bluetoothctl info "$mac" | awk -F'[(|)]' '/Battery Percentage:/ {print $2}')
            [ -z "$bat" ] && bat="0"

            if is_airpods "$mac" "$name"; then pods="true"; else pods="false"; fi

            connected_list_objs+=("{\"id\":\"$mac\",\"name\":\"$CACHE_NAME\",\"mac\":\"$mac\",\"icon\":\"$CACHE_ICON\",\"battery\":\"$bat\",\"profile\":\"$CACHE_PROFILE\",\"airpods\":$pods}")
        done

        if [ ${#connected_list_objs[@]} -gt 0 ]; then
            connected_json="[$(IFS=,; echo "${connected_list_objs[*]}")]"
        fi

        # 2. PROCESS DISCOVERED & PAIRED DEVICES
        for line in "${devices[@]}"; do
            [ -z "$line" ] && continue
            rest="${line#Device }"
            mac="${rest%% *}"
            
            if [[ "$connected_macs" == *"$mac"* ]]; then continue; fi

            name="${rest#* }"
            name_esc="${name//\"/\\\"}"

            if [[ "$paired_macs" == *"$mac"* ]]; then
                action="Connect"
            else
                action="Pair"
                
                # --- CONFIGURABLE SPAM FILTER ---
                if [[ "$STRICT_SPAM_FILTER" == true ]]; then
                    mac_hyphens="${mac//:/-}"
                    if [[ "$name" == "$mac" || "$name" == "$mac_hyphens" || -z "$name" ]]; then
                        continue
                    fi
                fi
            fi

            icon=$(get_icon "unknown" "$name")
            icon_esc="${icon//\"/\\\"}"

            devices_list_objs+=("{\"id\":\"$mac\",\"name\":\"$name_esc\",\"mac\":\"$mac\",\"icon\":\"$icon_esc\",\"action\":\"$action\"}")
        done

        if [ ${#devices_list_objs[@]} -gt 0 ]; then
            devices_json="[$(IFS=,; echo "${devices_list_objs[*]}")]"
        fi
    fi

    echo "{\"power\":\"$power\",\"anc\":\"$(anc_get)\",\"connected\":$connected_json,\"devices\":$devices_json}"
}

toggle_power() {
    if bluetoothctl show | grep -q "Powered: yes"; then
        bluetoothctl power off
    else
        bluetoothctl power on
    fi
    sleep 0.5
}

connect_dev() {
    local mac="$1"
    if [ -f "$PID_FILE" ]; then kill -STOP $(cat "$PID_FILE") 2>/dev/null; fi
    bluetoothctl trust "$mac" > /dev/null 2>&1
    bluetoothctl connect "$mac"
    if [ -f "$PID_FILE" ]; then kill -CONT $(cat "$PID_FILE") 2>/dev/null; fi
}

disconnect_dev() {
    local mac="$1"
    rm -f "$CACHE_DIR/bt_stat_${mac//:/_}" 2>/dev/null
    bluetoothctl disconnect "$mac"
}

# off -> anc -> transparency -> adaptive -> off
anc_cycle() {
    local cur next
    cur=$(anc_get)
    case "$cur" in
        off)          next="anc" ;;
        anc)          next="transparency" ;;
        transparency) next="adaptive" ;;
        adaptive)     next="off" ;;
        *)            next="anc" ;;
    esac
    anc_set "$next"
}

cmd="$1"
case $cmd in
    --status) get_status ;;
    --toggle) toggle_power ;;
    --connect) connect_dev "$2" ;;
    --disconnect) disconnect_dev "$2" ;;
    --anc) anc_set "$2" ;;
    --anc-get) anc_get ;;
    --anc-cycle) anc_cycle ;;
esac
