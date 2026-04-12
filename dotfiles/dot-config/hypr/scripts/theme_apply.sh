#!/usr/bin/env bash
# theme_apply.sh – Unified theme engine for dotfiles
# Usage: theme_apply.sh <theme-name|wallpaper> [--no-reload]
#
# Reads a theme JSON and generates per-app color configs.
# In wallpaper mode, reads the matugen-generated qs_colors.json.
# In manual mode, copies a theme file from ~/.config/hypr/themes/.

set -euo pipefail

THEME_DIR="$HOME/.config/hypr/themes"
QS_JSON="$HOME/.config/hypr/scripts/quickshell/qs_colors.json"
STATE_FILE="$HOME/.cache/current_theme"

mode="${1:-}"
skip_reload="${2:-}"

if [ -z "$mode" ]; then
    echo "Usage: theme_apply.sh <theme-name|wallpaper> [--no-reload]"
    echo "Available themes:"
    for f in "$THEME_DIR"/*.json; do
        [ -f "$f" ] && basename "$f" .json
    done
    echo "wallpaper"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════
# 1. Determine theme source
# ═══════════════════════════════════════════════════════════════════
if [ "$mode" = "wallpaper" ]; then
    # Flatten matugen v4.0 nested JSON if needed
    python3 - "$QS_JSON" << 'PYEOF'
import json, sys
def flat(o):
    if isinstance(o, dict):
        if "color" in o and isinstance(o["color"], str): return o["color"]
        return {k: flat(v) for k, v in o.items()}
    return o
p = sys.argv[1]
try:
    d = json.load(open(p)); json.dump(flat(d), open(p, "w"), indent=2)
except Exception:
    pass
PYEOF
    echo "wallpaper" > "$STATE_FILE"
elif [ -f "$THEME_DIR/${mode}.json" ]; then
    mkdir -p "$(dirname "$QS_JSON")"
    cp "$THEME_DIR/${mode}.json" "$QS_JSON"
    echo "$mode" > "$STATE_FILE"
else
    echo "Error: Unknown theme '$mode'"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════
# 2. Read all color values from the JSON
# ═══════════════════════════════════════════════════════════════════
g() { jq -r ".$1 // empty" "$QS_JSON"; }

BASE=$(g base)         MANTLE=$(g mantle)       CRUST=$(g crust)
TEXT=$(g text)          SUBTEXT0=$(g subtext0)   SUBTEXT1=$(g subtext1)
SURFACE0=$(g surface0) SURFACE1=$(g surface1)   SURFACE2=$(g surface2)
OVERLAY0=$(g overlay0) OVERLAY1=$(g overlay1)   OVERLAY2=$(g overlay2)

BLUE=$(g blue)       SAPPHIRE=$(g sapphire)   PEACH=$(g peach)
GREEN=$(g green)     RED=$(g red)             MAUVE=$(g mauve)
PINK=$(g pink)       YELLOW=$(g yellow)       MAROON=$(g maroon)
TEAL=$(g teal)

ACCENT=$(g accent);          ACCENT=${ACCENT:-$BLUE}
ACCENT_DIM=$(g accent_dim);  ACCENT_DIM=${ACCENT_DIM:-$SAPPHIRE}
ACCENT_BRIGHT=$(g accent_bright); ACCENT_BRIGHT=${ACCENT_BRIGHT:-$TEAL}
SELECTION=$(g selection);    SELECTION=${SELECTION:-$SURFACE1}
BORDER=$(g border);          BORDER=${BORDER:-$SURFACE2}

# Terminal 16 colors (fallback to main palette)
TB=$(g term_black);    TB=${TB:-$CRUST}
TR=$(g term_red);      TR=${TR:-$RED}
TG=$(g term_green);    TG=${TG:-$GREEN}
TY=$(g term_yellow);   TY=${TY:-$YELLOW}
TBL=$(g term_blue);    TBL=${TBL:-$BLUE}
TMA=$(g term_magenta); TMA=${TMA:-$MAUVE}
TC=$(g term_cyan);     TC=${TC:-$TEAL}
TW=$(g term_white);    TW=${TW:-$TEXT}
TBB=$(g term_bright_black);    TBB=${TBB:-$OVERLAY0}
TBR=$(g term_bright_red);      TBR=${TBR:-$PINK}
TBG=$(g term_bright_green);    TBG=${TBG:-$GREEN}
TBY=$(g term_bright_yellow);   TBY=${TBY:-$YELLOW}
TBBL=$(g term_bright_blue);    TBBL=${TBBL:-$SAPPHIRE}
TBM=$(g term_bright_magenta);  TBM=${TBM:-$MAROON}
TBC=$(g term_bright_cyan);     TBC=${TBC:-$TEAL}
TBW=$(g term_bright_white);    TBW=${TBW:-$TEXT}

RAD_S=$(g radius_small);  RAD_S=${RAD_S:-4}
RAD_M=$(g radius_medium); RAD_M=${RAD_M:-10}
RAD_L=$(g radius_large);  RAD_L=${RAD_L:-16}

# Helper: strip leading # from hex color
s() { echo "${1#\#}"; }

# Helper: convert #rrggbb to "r, g, b" decimal for CSS rgba()
hex2rgb() {
    local h="${1#\#}"
    printf "%d, %d, %d" "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

# ═══════════════════════════════════════════════════════════════════
# 3. Helper: replace content between theme markers in a file
# ═══════════════════════════════════════════════════════════════════
replace_theme_block() {
    local file="$1"
    local content="$2"
    [ -f "$file" ] || return 0

    awk -v content="$content" '
    /theme-colors-start/ {
        print
        printf "%s\n", content
        skip = 1
        next
    }
    /theme-colors-end/ {
        skip = 0
        print
        next
    }
    !skip { print }
    ' "$file" > "${file}.tmp" && cp "${file}.tmp" "$file" && rm -f "${file}.tmp"
}

# ═══════════════════════════════════════════════════════════════════
# 4. Generate GTK CSS color blocks
# ═══════════════════════════════════════════════════════════════════

# --- Waybar ---
WAYBAR_COLORS="@define-color bg_base ${BASE};
@define-color bg_mantle ${MANTLE};
@define-color bg_crust ${CRUST};
@define-color bg_surface0 ${SURFACE0};
@define-color bg_surface1 ${SURFACE1};
@define-color bg_surface2 ${SURFACE2};
@define-color text_primary ${TEXT};
@define-color text_secondary ${SUBTEXT0};
@define-color text_muted ${SUBTEXT1};
@define-color overlay0 ${OVERLAY0};
@define-color overlay1 ${OVERLAY1};
@define-color overlay2 ${OVERLAY2};
@define-color accent ${ACCENT};
@define-color accent_dim ${ACCENT_DIM};
@define-color accent_bright ${ACCENT_BRIGHT};
@define-color blue ${BLUE};
@define-color sapphire ${SAPPHIRE};
@define-color green ${GREEN};
@define-color red ${RED};
@define-color yellow ${YELLOW};
@define-color peach ${PEACH};
@define-color mauve ${MAUVE};
@define-color pink ${PINK};
@define-color maroon ${MAROON};
@define-color teal ${TEAL};
@define-color selection ${SELECTION};
@define-color border_subtle rgba($(hex2rgb "$BORDER"), 0.6);"

replace_theme_block "$HOME/.config/waybar/style.css" "$WAYBAR_COLORS"

# --- Wofi ---
WOFI_COLORS="@define-color bg_base ${BASE};
@define-color bg_crust ${CRUST};
@define-color text_primary ${TEXT};
@define-color text_bright ${ACCENT_BRIGHT};
@define-color selection ${SELECTION};
@define-color border_color ${CRUST};"

replace_theme_block "$HOME/.config/wofi/style.css" "$WOFI_COLORS"

# --- SwayNC ---
SWAYNC_COLORS="@define-color cc-bg ${BASE};
@define-color noti-border-color ${BORDER};
@define-color noti-bg ${MANTLE};
@define-color noti-bg-darker ${SURFACE0};
@define-color noti-bg-hover ${SURFACE1};
@define-color noti-bg-focus ${SURFACE0};
@define-color noti-close-bg ${RED};
@define-color noti-close-bg-hover ${PINK};
@define-color text-color ${TEXT};
@define-color text-color-disabled ${SUBTEXT1};
@define-color bg-selected ${ACCENT};
@define-color border-blue ${ACCENT_DIM};
@define-color red-base ${RED};
@define-color red-hover ${PINK};
@define-color green-base ${GREEN};
@define-color blue-base ${ACCENT};"

replace_theme_block "$HOME/.config/swaync/style.css" "$SWAYNC_COLORS"

# --- Wlogout ---
WLOGOUT_COLORS="@define-color bg_base ${BASE};
@define-color selection ${SELECTION};
@define-color text_primary ${TEXT};
@define-color border_color ${BORDER};"

replace_theme_block "$HOME/.config/wlogout/style.css" "$WLOGOUT_COLORS"

# --- Nwg-dock ---
NWG_COLORS="@define-color bg_base ${BASE};
@define-color border_subtle rgba($(hex2rgb "$BORDER"), 0.6);
@define-color text_primary ${TEXT};
@define-color text_dim ${SUBTEXT0};
@define-color text_muted ${SUBTEXT1};
@define-color hover_bg rgba($(hex2rgb "$SURFACE0"), 0.8);
@define-color active_border rgba($(hex2rgb "$BORDER"), 0.5);"

replace_theme_block "$HOME/.config/nwg-dock-hyprland/style.css" "$NWG_COLORS"

# ═══════════════════════════════════════════════════════════════════
# 5. Hyprland colors.conf (sourced by hyprland.conf)
# ═══════════════════════════════════════════════════════════════════
cat > "$HOME/.config/hypr/colors.conf" << EOF
# Auto-generated by theme_apply.sh — do not edit manually
\$theme_bg = rgb($(s "$BASE"))
\$theme_mantle = rgb($(s "$MANTLE"))
\$theme_crust = rgb($(s "$CRUST"))
\$theme_surface0 = rgb($(s "$SURFACE0"))
\$theme_surface1 = rgb($(s "$SURFACE1"))
\$theme_text = rgb($(s "$TEXT"))
\$theme_accent = rgb($(s "$ACCENT"))
\$theme_border = rgba($(s "$BORDER")aa)
\$theme_border_inactive = rgba($(s "$CRUST")66)
\$theme_red = rgb($(s "$RED"))
\$theme_green = rgb($(s "$GREEN"))
\$theme_yellow = rgb($(s "$YELLOW"))
\$theme_blue = rgb($(s "$BLUE"))
\$theme_mauve = rgb($(s "$MAUVE"))
\$theme_rounding = ${RAD_L}
EOF

# ═══════════════════════════════════════════════════════════════════
# 6. Hyprlock colors (sourced by hyprlock.conf)
# ═══════════════════════════════════════════════════════════════════
cat > "$HOME/.config/hypr/hyprlock-colors.conf" << EOF
# Auto-generated by theme_apply.sh
\$lock_text = rgba($(s "$TEXT")ee)
\$lock_text_dim = rgba($(s "$SUBTEXT0")cc)
\$lock_ring = rgb($(s "$OVERLAY2"))
\$lock_ring_check = rgb($(s "$GREEN"))
\$lock_ring_fail = rgb($(s "$RED"))
\$lock_bg = rgba($(s "$CRUST")ff)
\$lock_input_inner = rgba(0, 0, 0, 0.0)
EOF

# ═══════════════════════════════════════════════════════════════════
# 7. Alacritty theme
# ═══════════════════════════════════════════════════════════════════
mkdir -p "$HOME/.config/alacritty/themes"
cat > "$HOME/.config/alacritty/themes/current.toml" << EOF
# Auto-generated by theme_apply.sh
[colors.primary]
background = '${BASE}'
foreground = '${TEXT}'

[colors.cursor]
text = "${BASE}"
cursor = "${SAPPHIRE}"

[colors.normal]
black = '${TB}'
red = '${TR}'
green = '${TG}'
yellow = '${TY}'
blue = '${TBL}'
magenta = '${TMA}'
cyan = '${TC}'
white = '${TW}'

[colors.bright]
black = '${TBB}'
red = '${TBR}'
green = '${TBG}'
yellow = '${TBY}'
blue = '${TBBL}'
magenta = '${TBM}'
cyan = '${TBC}'
white = '${TBW}'
EOF

# ═══════════════════════════════════════════════════════════════════
# 8. Ghostty colors (marker-based replacement)
# ═══════════════════════════════════════════════════════════════════
GHOSTTY_CFG="$HOME/.config/ghostty/config"
if [ -f "$GHOSTTY_CFG" ]; then
    GHOSTTY_COLORS="background = $(s "$BASE")
foreground = $(s "$TEXT")
palette = 0=$(s "$TB")
palette = 1=$(s "$TR")
palette = 2=$(s "$TG")
palette = 3=$(s "$TY")
palette = 4=$(s "$TBL")
palette = 5=$(s "$TMA")
palette = 6=$(s "$TC")
palette = 7=$(s "$TW")
palette = 8=$(s "$TBB")
palette = 9=$(s "$TBR")
palette = 10=$(s "$TBG")
palette = 11=$(s "$TBY")
palette = 12=$(s "$TBBL")
palette = 13=$(s "$TBM")
palette = 14=$(s "$TBC")
palette = 15=$(s "$TBW")"

    replace_theme_block "$GHOSTTY_CFG" "$GHOSTTY_COLORS"
fi

# ═══════════════════════════════════════════════════════════════════
# 9. Neovim colors (lua table)
# ═══════════════════════════════════════════════════════════════════
mkdir -p "$HOME/.config/nvim/lua/filip"
cat > "$HOME/.config/nvim/lua/filip/theme_colors.lua" << EOF
-- Auto-generated by theme_apply.sh
return {
    bg = "${BASE}",
    bg_dark = "${MANTLE}",
    bg_highlight = "${SURFACE1}",
    bg_search = "${ACCENT_DIM}",
    bg_visual = "${SELECTION}",
    fg = "${TEXT}",
    fg_dark = "${SUBTEXT0}",
    fg_gutter = "${SUBTEXT1}",
    border = "${OVERLAY2}",
}
EOF

# ═══════════════════════════════════════════════════════════════════
# 10. Kitty colors (if kitty config dir exists)
# ═══════════════════════════════════════════════════════════════════
if [ -d "$HOME/.config/kitty" ]; then
    cat > "$HOME/.config/kitty/theme-colors.conf" << EOF
# Auto-generated by theme_apply.sh
background ${BASE}
foreground ${TEXT}
cursor ${SAPPHIRE}
color0  ${TB}
color1  ${TR}
color2  ${TG}
color3  ${TY}
color4  ${TBL}
color5  ${TMA}
color6  ${TC}
color7  ${TW}
color8  ${TBB}
color9  ${TBR}
color10 ${TBG}
color11 ${TBY}
color12 ${TBBL}
color13 ${TBM}
color14 ${TBC}
color15 ${TBW}
EOF
fi

# ═══════════════════════════════════════════════════════════════════
# 11. Reload applications
# ═══════════════════════════════════════════════════════════════════
if [ "$skip_reload" != "--no-reload" ]; then
    # Kitty
    killall -USR1 kitty 2>/dev/null || true

    # Ghostty (reload via DBus)
    busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate "sava{sv}" "reload-config" 0 0 2>/dev/null || true

    # Waybar (full restart to pick up new colors)
    killall waybar 2>/dev/null || true
    waybar > /dev/null 2>&1 &
    disown

    # SwayNC (full restart for CSS changes)
    killall swaync 2>/dev/null || true
    swaync > /dev/null 2>&1 &
    disown

    # Hyprland (reloads config including colors.conf)
    hyprctl reload 2>/dev/null || true

    # CAVA (rebuild config from base + generated colors)
    if [ -f "$HOME/.config/cava/config_base" ] && [ -f "$HOME/.config/cava/colors" ]; then
        cat "$HOME/.config/cava/config_base" "$HOME/.config/cava/colors" > "$HOME/.config/cava/config" 2>/dev/null
        pgrep -x cava >/dev/null && killall -USR1 cava 2>/dev/null || true
    fi

    # Swayosd
    if pgrep -x swayosd-server >/dev/null 2>&1; then
        killall swayosd-server 2>/dev/null || true
        swayosd-server --top-margin 0.9 --style "$HOME/.config/swayosd/style.css" > /dev/null 2>&1 &
    fi

    notify-send -a "Theme" "Theme Applied" "$(cat "$STATE_FILE" 2>/dev/null || echo "$mode")" 2>/dev/null || true
fi
