#!/bin/bash
SLURP_ARGS="-b 1B1F2844 -c E06B74ff -s C778DD0D -w 2"
GEOMETRY=$(slurp $SLURP_ARGS) || exit 0
grim -g "$GEOMETRY" - | wl-copy
notify-send -a "Screenshot" "Screenshot Copied" "Copied to clipboard"
