
file="$HOME/.config/hypr/hyprland.conf"

if [[ ! -f "$file" ]]; then
    echo "File not found: $file"
    exit 1
fi


if grep -q "kb_layout = us" "$file"; then
    sed -i 's|kb_layout = us|kb_layout = no|' "$file"
    notify-send "Set keyboard layout to Norwegian"
    echo "Changed layout to no in $file"

elif grep -q "kb_layout = no" "$file"; then
    sed -i 's|kb_layout = no|kb_layout = us|' "$file"
    notify-send "Set keyboard layout to American"
    echo "Changed layout to us in $file"
fi

hyprctl reload
