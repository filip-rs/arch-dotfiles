#!/bin/bash
#SLURP_ARGS="-b 1B1F2855 -c E06B74ff -s C778DD0D -w 0"
SLURP_ARGS="-b bbbbbb11 -w 0"
GEOMETRY=$(slurp $SLURP_ARGS) || exit 0
grim -g "$GEOMETRY" - | wl-copy
notify-send -a "Screenshot" "Screenshot Copied" "Copied to clipboard"
