#!/usr/bin/env bash

POWER=$(nmcli radio wifi)

if [[ "$POWER" == "disabled" ]]; then
    echo '{ "power": "off", "connected": null, "networks": [] }'
    exit 0
fi

get_icon() {
    local signal=$1
    if [[ $signal -ge 80 ]]; then echo "󰤨";
    elif [[ $signal -ge 60 ]]; then echo "󰤥";
    elif [[ $signal -ge 40 ]]; then echo "󰤢";
    elif [[ $signal -ge 20 ]]; then echo "󰤟";
    else echo "󰤯"; fi
}

# Escape a string for use inside a JSON string literal.
json_str() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//[[:cntrl:]]/}"
    printf '%s' "$s"
}

CACHE_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/quickshell_network_cache"
mkdir -p "$CACHE_DIR"

# SSIDs are arbitrary bytes from whoever is broadcasting nearby. With
# `--escape no` nmcli doesn't backslash-escape ':' and '\', and with the SSID
# as the last field it is simply everything after the third ':'.
CURRENT_RAW=$(nmcli -t -e no -f active,signal,security,ssid device wifi | awk -F: '$1=="yes"{print; exit}')

if [[ -n "$CURRENT_RAW" ]]; then
    IFS=':' read -r active signal security ssid <<< "$CURRENT_RAW"
    icon=$(get_icon "$signal")
    
    SAFE_SSID="${ssid//[^a-zA-Z0-9]/_}"
    CACHE_FILE="$CACHE_DIR/wifi_$SAFE_SSID"
    
    if [ -f "$CACHE_FILE" ]; then
        source "$CACHE_FILE"
    fi
    
    if [ -z "$IP" ] || [ "$IP" == "No IP" ] || [ -z "$FREQ" ]; then
        IFACE=$(nmcli -t -f DEVICE,TYPE d | awk -F: '$2=="wifi"{print $1;exit}')
        IP=$(ip -4 addr show dev "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        [ -z "$IP" ] && IP="No IP"
        
        FREQ=$(iw dev "$IFACE" link 2>/dev/null | awk '/freq:/ {print $2}')
        [ -n "$FREQ" ] && FREQ="${FREQ} MHz" || FREQ="Unknown"
        
        echo "IP=\"$IP\"" > "$CACHE_FILE"
        echo "FREQ=\"$FREQ\"" >> "$CACHE_FILE"
    fi

    # Native Bash JSON generation
    ssid_esc=$(json_str "$ssid")
    sec_esc=$(json_str "$security")
    icon_esc=$(json_str "$icon")
    CONNECTED_JSON="{\"id\":\"$ssid_esc\",\"ssid\":\"$ssid_esc\",\"icon\":\"$icon_esc\",\"signal\":\"$signal\",\"security\":\"$sec_esc\",\"ip\":\"$IP\",\"freq\":\"$FREQ\"}"
else
    CONNECTED_JSON="null"
fi

# AWK processes the entire network list natively, zero sub-shells
NETWORKS_JSON=$(nmcli -t -e no -f active,signal,security,ssid device wifi list --rescan no | awk -F: '
    # JSON string escaping: backslashes first ("&&" doubles the match), then
    # quotes; control characters are dropped.
    function esc(v) { gsub(/\\/, "&&", v); gsub(/"/, "\\\\&", v); gsub(/[\001-\037]/, "", v); return v }
    {
        ssid = $0; sub(/^[^:]*:[^:]*:[^:]*:/, "", ssid);
    }
    ssid != "" && $1 != "yes" && !seen[ssid]++ {
        signal=$2;
        ssid=esc(ssid); security=esc($3);
        
        if (signal >= 80) icon="󰤨";
        else if (signal >= 60) icon="󰤥";
        else if (signal >= 40) icon="󰤢";
        else if (signal >= 20) icon="󰤟";
        else icon="󰤯";
        
        printf "{\"id\":\"%s\",\"ssid\":\"%s\",\"icon\":\"%s\",\"signal\":\"%s\",\"security\":\"%s\"}\n", ssid, ssid, icon, signal, security
    }
' | head -n 24 | paste -sd, -)

if [ -z "$NETWORKS_JSON" ]; then
    NETWORKS_JSON="[]"
else
    NETWORKS_JSON="[$NETWORKS_JSON]"
fi

# Final JSON output
echo "{\"power\":\"on\",\"connected\":$CONNECTED_JSON,\"networks\":$NETWORKS_JSON}"
