matrix_size=9

## Functions
function reload_waybar {
	kill -SIGRTMIN+1 $(pgrep waybar)
}

function clamp {
    # Clamp coordinates to 1-3 range for 3x3 matrix
    echo $(($1 > 3 ? 3 : $(($1 < 1 ? 1 : $1))))
}

function is_valid_workspace {
    # Check if workspace ID is one of the 9 allowed workspaces
    case "$1" in
        "1"|"2"|"3"|"257"|"258"|"259"|"513"|"514"|"515") return 0 ;;
        *) return 1 ;;
    esac
}

function x_value {
	echo $((($1 - 1 & 255) + 1))
}

function y_value {
	echo $((($1 - 1 >> 8) + 1))
}

function show_all {
	hyprctl workspaces -j | jq '.[]."id"' | sort -g | while read id; do echo -n "($(x_value $id),$(y_value $id)) "; done
}

## Check for command "all"
case "$1" in
	"all") show_all; exit ;;
esac;

## Get active workspace and translate to x / y

active_ws=$(hyprctl monitors -j | jq '.[]."activeWorkspace"."id"')

# If current workspace is not one of the 9 allowed, default to 258
if ! is_valid_workspace $active_ws; then
    active_ws=258
fi

#echo $active_ws 1>&2
x=$(x_value $active_ws)
y=$(y_value $active_ws)

#echo "($x,$y)" 1>&2

case "$1" in
	"left" | "move_left") x=$(clamp $(($x - 1))) ;;
	"right" | "move_right") x=$(clamp $(($x + 1))) ;;
	"up" | "move_up") y=$(clamp $(($y - 1))) ;;
	"down" | "move_down") y=$(clamp $(($y + 1))) ;;
	"query") echo "($x,$y)"; exit ;;
esac

#echo "($x,$y)" 1>&2

## Generate new workspace number
ws=$(( $(( (y-1) << 8 )) + x ))
#echo $ws 1>&2

case "$1" in
	"left" | "right" | "up" | "down") hyprctl dispatch workspace $ws ;;
	"move_left" | "move_right" | "move_up" | "move_down") hyprctl dispatch movetoworkspace $ws ;;
esac

reload_waybar
