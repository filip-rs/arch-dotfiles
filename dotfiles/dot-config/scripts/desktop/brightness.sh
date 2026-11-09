#!/usr/bin/env bash
# brightness.sh up|down|min|max|kbd-up|kbd-down
#
# Screen brightness moves along a ladder that is fine near the bottom and
# coarse near the top: the steps grow like Fibonacci (1, 2, 3, 5, 8) and are
# capped at 10 points, so the top is reached in tens rather than in one jump.
# A value between two rungs (set elsewhere) snaps to the next rung in the
# direction pressed. SwayOSD sets the value and shows the popup.
#
# The keyboard backlight has only a few hardware levels; it steps by one and
# shows them as a segmented bar.

LEVELS=(1 2 4 7 12 20 30 40 50 60 70 80 90 100)

screen() {
    local cur max pct10 target="" i
    cur=$(brightnessctl -c backlight g 2>/dev/null)
    max=$(brightnessctl -c backlight m 2>/dev/null)
    [ -n "$max" ] && [ "$max" -gt 0 ] || exit 0 # no backlight (desktop monitors)
    pct10=$(( cur * 1000 / max ))               # tenths of a percent

    case "$1" in
        up)
            for i in "${LEVELS[@]}"; do
                (( i * 10 > pct10 + 4 )) && { target=$i; break; }
            done
            target=${target:-100}
            ;;
        down)
            for (( i = ${#LEVELS[@]} - 1; i >= 0; i-- )); do
                (( LEVELS[i] * 10 < pct10 - 4 )) && { target=${LEVELS[i]}; break; }
            done
            target=${target:-${LEVELS[0]}}
            ;;
        min) target=${LEVELS[0]} ;;
        max) target=100 ;;
    esac
    swayosd-client --brightness "$target"
}

keyboard() {
    local dev cur max
    dev=$(brightnessctl -l -m -c leds 2>/dev/null | grep -m1 kbd_backlight | cut -d, -f1)
    [ -n "$dev" ] || exit 0
    if [ "$1" = up ]; then brightnessctl -q -d "$dev" set +1; else brightnessctl -q -d "$dev" set 1-; fi
    cur=$(brightnessctl -d "$dev" g)
    max=$(brightnessctl -d "$dev" m)
    swayosd-client --custom-segmented-progress "$cur:$max" --custom-icon keyboard-brightness-symbolic
}

case "${1:-}" in
    up|down|min|max) screen "$1" ;;
    kbd-up)          keyboard up ;;
    kbd-down)        keyboard down ;;
    *) echo "usage: brightness.sh up|down|min|max|kbd-up|kbd-down" >&2; exit 1 ;;
esac
