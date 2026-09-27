#!/usr/bin/env bash
# Cycle the keyboard layout between us (altgr-intl) and no.
# Bound to SUPER + CTRL + SHIFT + SPACE.
#
# Both layouts are declared in lua/input.lua as `kb_layout = "us,no"`, so this
# just asks Hyprland to switch index. It no longer sed-edits the config file
# (which used to dirty the git worktree on every press).

hyprctl switchxkblayout current next >/dev/null

LAYOUT=$(hyprctl devices -j | jq -r '[.keyboards[] | select(.main == true)][0].active_keymap')

case "$LAYOUT" in
    *Norwegian*) notify-send "Keyboard" "Norwegian" ;;
    *English*)   notify-send "Keyboard" "American" ;;
    *)           notify-send "Keyboard" "${LAYOUT:-unknown}" ;;
esac
