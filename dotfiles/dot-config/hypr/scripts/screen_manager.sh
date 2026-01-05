
if [ "$(hyprctl monitors -j | jq '.[] | select(.name == "DP-2") | .dpmsStatus')" = "false" ]; then
    hyprctl dispatch dpms on DP-2
    hyprctl dispatch dpms on DP-3

    notify-send "Enabling displays" "Exitting focus mode"

else
    hyprctl dispatch dpms off DP-2
    hyprctl dispatch dpms off DP-3

    notify-send "Disabling displays" "Entering focus mode"

fi
