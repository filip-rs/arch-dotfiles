
file="$HOME/.config/hypr/hyprland.conf"

if [[ ! -f "$file" ]]; then
    echo "File not found: $file"
    exit 1
fi


if grep -q "monitor=eDP-1,1920x1200@60, 0x0, 1.0" "$file"; then
    sed -i 's|monitor=eDP-1,1920x1200@60, 0x0, 1.0|monitor=eDP-1,1920x1200@120, 0x0, 1.0|' "$file"
    notify-send "Set refreshrate to 120hz"
    echo "Changed refreshrate to 120hz in $file"

elif grep -q "monitor=eDP-1,1920x1200@120, 0x0, 1.0" "$file"; then
    sed -i 's|monitor=eDP-1,1920x1200@120, 0x0, 1.0|monitor=eDP-1,1920x1200@60, 0x0, 1.0|' "$file"
    notify-send "Set refreshrate to 60hz"
    echo "Changed refreshrate to 60hz in $file"
fi

hyprctl reload
