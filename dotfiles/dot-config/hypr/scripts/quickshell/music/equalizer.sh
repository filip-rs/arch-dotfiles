#!/usr/bin/env bash
# 10-band EQ using PipeWire filter-chain (replaces easyeffects)

STATE_FILE="/tmp/eq_state.json"
CONFIG_DIR="$HOME/.config/pipewire/filter-chain.conf.d"
CONFIG_FILE="$CONFIG_DIR/eq-live.conf"
PID_FILE="/tmp/pw_eq_pid"
EQ_SINK="effect_input.live_eq"

# Standard ISO 10-band frequencies
FREQS=(32 63 125 250 500 1000 2000 4000 8000 16000)
TYPES=("bq_lowshelf" "bq_peaking" "bq_peaking" "bq_peaking" "bq_peaking" "bq_peaking" "bq_peaking" "bq_peaking" "bq_peaking" "bq_highshelf")

mkdir -p "$CONFIG_DIR"

if [ ! -f "$STATE_FILE" ]; then
    echo '{"b1":0,"b2":0,"b3":0,"b4":0,"b5":0,"b6":0,"b7":0,"b8":0,"b9":0,"b10":0,"preset":"Flat","pending":false}' > "$STATE_FILE"
fi

read_gains() {
    local vals=$(cat "$STATE_FILE")
    GAINS=()
    for i in $(seq 1 10); do
        local g=$(echo "$vals" | jq -r ".b${i}")
        [[ "$g" != *.* ]] && g="${g}.0"
        GAINS+=("$g")
    done
}

generate_config() {
    read_gains

    local nodes="" links=""
    for i in $(seq 0 9); do
        local band=$((i + 1))
        nodes+="
                    {
                        type  = builtin
                        name  = eq_band_${band}
                        label = ${TYPES[$i]}
                        control = { \"Freq\" = ${FREQS[$i]}.0 \"Q\" = 1.0 \"Gain\" = ${GAINS[$i]} }
                    }"
    done
    for i in $(seq 1 9); do
        links+="
                    { output = \"eq_band_${i}:Out\" input = \"eq_band_$((i + 1)):In\" }"
    done

    cat > "$CONFIG_FILE" << EOF
context.modules = [
    { name = libpipewire-module-filter-chain
        args = {
            node.description = "Live EQ"
            media.name       = "Live EQ"
            filter.graph = {
                nodes = [${nodes}
                ]
                links = [${links}
                ]
            }
            audio.channels = 2
            audio.position = [ FL FR ]
            capture.props = {
                node.name   = "${EQ_SINK}"
                media.class = Audio/Sink
            }
            playback.props = {
                node.name   = "effect_output.live_eq"
                node.passive = true
            }
        }
    }
]
EOF
}

start_eq() {
    # Kill existing filter-chain EQ
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null
        rm -f "$PID_FILE"
    fi
    sleep 0.2

    pipewire -c filter-chain.conf >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
    disown

    # Wait for sink to appear, set as default, move existing streams
    for _ in $(seq 1 20); do
        if pactl list sinks short 2>/dev/null | grep -q "$EQ_SINK"; then
            pactl set-default-sink "$EQ_SINK" 2>/dev/null
            for input in $(pactl list sink-inputs short 2>/dev/null | awk '{print $1}'); do
                pactl move-sink-input "$input" "$EQ_SINK" 2>/dev/null
            done
            return 0
        fi
        sleep 0.1
    done
}

try_live_update() {
    read_gains
    local node_id
    node_id=$(pw-dump 2>/dev/null | jq -r \
        ".[] | select(.type == \"PipeWire:Interface:Node\" and .info.props.\"node.name\"? == \"${EQ_SINK}\") | .id" \
        | head -1)

    [ -z "$node_id" ] || [ "$node_id" = "null" ] && return 1

    local params=""
    for i in $(seq 1 10); do
        params+="\"eq_band_${i}:Gain\" ${GAINS[$((i - 1))]} "
    done

    pw-cli set-param "$node_id" Props "{ params = [ ${params}] }" 2>/dev/null
}

apply_eq() {
    generate_config
    # Try live update (instant, no audio blip), fall back to restart
    try_live_update || start_eq
}

save_preset() {
    jq -n -c --arg b1 "$1" --arg b2 "$2" --arg b3 "$3" --arg b4 "$4" --arg b5 "$5" \
          --arg b6 "$6" --arg b7 "$7" --arg b8 "$8" --arg b9 "$9" --arg b10 "${10}" --arg p "${11}" \
       '{"b1":$b1,"b2":$b2,"b3":$b3,"b4":$b4,"b5":$b5,"b6":$b6,"b7":$b7,"b8":$b8,"b9":$b9,"b10":$b10,"preset":$p,"pending":false}' > "$STATE_FILE"
}

cmd=$1
arg1=$2
arg2=$3

case $cmd in
    "get") cat "$STATE_FILE" ;;
    "set_band")
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c --arg val "$arg2" ".b$arg1 = \$val | .preset = \"Custom\" | .pending = true")
        echo "$updated" > "$STATE_FILE"
        ;;
    "apply")
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c ".pending = false")
        echo "$updated" > "$STATE_FILE"
        apply_eq
        ;;
    "preset")
        case $arg1 in
            "Flat")    save_preset 0 0 0 0 0 0 0 0 0 0 "Flat" ;;
            "Bass")    save_preset 5 7 5 2 1 0 0 0 1 2 "Bass" ;;
            "Treble")  save_preset -2 -1 0 1 2 3 4 5 6 6 "Treble" ;;
            "Vocal")   save_preset -2 -1 1 3 5 5 4 2 1 0 "Vocal" ;;
            "Pop")     save_preset 2 4 2 0 1 2 4 2 1 2 "Pop" ;;
            "Rock")    save_preset 5 4 2 -1 -2 -1 2 4 5 6 "Rock" ;;
            "Jazz")    save_preset 3 3 1 1 1 1 2 1 2 3 "Jazz" ;;
            "Classic") save_preset 0 1 2 2 2 2 1 2 3 4 "Classic" ;;
        esac
        apply_eq
        ;;
esac
