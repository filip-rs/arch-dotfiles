#!/usr/bin/env bash
# theme_apply.sh – Unified theme engine for dotfiles
# Usage: theme_apply.sh <theme-name|wallpaper> [--no-reload]
#
# Reads a theme JSON and generates per-app color configs.
# In wallpaper mode, reads the matugen-generated qs_colors.json.
# In manual mode, copies a theme file from ~/.config/scripts/desktop/themes/.

set -euo pipefail

source "$HOME/.config/scripts/lib/compositor.sh"
THEME_DIR="$HOME/.config/scripts/desktop/themes"
QS_JSON="$HOME/.config/quickshell/qs_colors.json"
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
if [ "$mode" = "wallpaper" ] || [ "$mode" = "wallpaper-light" ]; then
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
    echo "$mode" > "$STATE_FILE"
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
# One jq call loads the whole palette; ${P[key]} is empty for missing keys.
declare -A P
while IFS=$'\t' read -r key value; do P[$key]=$value; done < <(
    jq -r 'to_entries[] | select(.value | type == "string" or type == "number")
           | "\(.key)\t\(.value)"' "$QS_JSON")

BASE=${P[base]:-}         MANTLE=${P[mantle]:-}       CRUST=${P[crust]:-}
TEXT=${P[text]:-}          SUBTEXT0=${P[subtext0]:-}   SUBTEXT1=${P[subtext1]:-}
SURFACE0=${P[surface0]:-} SURFACE1=${P[surface1]:-}   SURFACE2=${P[surface2]:-}
OVERLAY0=${P[overlay0]:-} OVERLAY1=${P[overlay1]:-}   OVERLAY2=${P[overlay2]:-}

BLUE=${P[blue]:-}       SAPPHIRE=${P[sapphire]:-}   PEACH=${P[peach]:-}
GREEN=${P[green]:-}     RED=${P[red]:-}             MAUVE=${P[mauve]:-}
PINK=${P[pink]:-}       YELLOW=${P[yellow]:-}       MAROON=${P[maroon]:-}
TEAL=${P[teal]:-}

ACCENT=${P[accent]:-};          ACCENT=${ACCENT:-$BLUE}
ACCENT_DIM=${P[accent_dim]:-};  ACCENT_DIM=${ACCENT_DIM:-$SAPPHIRE}
ACCENT_BRIGHT=${P[accent_bright]:-}; ACCENT_BRIGHT=${ACCENT_BRIGHT:-$TEAL}
SELECTION=${P[selection]:-};    SELECTION=${SELECTION:-$SURFACE1}
BORDER=${P[border]:-};          BORDER=${BORDER:-$SURFACE2}

# Terminal 16 colors (fallback to main palette)
TB=${P[term_black]:-};    TB=${TB:-$CRUST}
TR=${P[term_red]:-};      TR=${TR:-$RED}
TG=${P[term_green]:-};    TG=${TG:-$GREEN}
TY=${P[term_yellow]:-};   TY=${TY:-$YELLOW}
TBL=${P[term_blue]:-};    TBL=${TBL:-$BLUE}
TMA=${P[term_magenta]:-}; TMA=${TMA:-$MAUVE}
TC=${P[term_cyan]:-};     TC=${TC:-$TEAL}
TW=${P[term_white]:-};    TW=${TW:-$TEXT}
TBB=${P[term_bright_black]:-};    TBB=${TBB:-$OVERLAY0}
TBR=${P[term_bright_red]:-};      TBR=${TBR:-$PINK}
TBG=${P[term_bright_green]:-};    TBG=${TBG:-$GREEN}
TBY=${P[term_bright_yellow]:-};   TBY=${TBY:-$YELLOW}
TBBL=${P[term_bright_blue]:-};    TBBL=${TBBL:-$SAPPHIRE}
TBM=${P[term_bright_magenta]:-};  TBM=${TBM:-$MAROON}
TBC=${P[term_bright_cyan]:-};     TBC=${TBC:-$TEAL}
TBW=${P[term_bright_white]:-};    TBW=${TBW:-$TEXT}

RAD_S=${P[radius_small]:-};  RAD_S=${RAD_S:-4}
RAD_M=${P[radius_medium]:-}; RAD_M=${RAD_M:-10}
RAD_L=${P[radius_large]:-};  RAD_L=${RAD_L:-16}

# Helper: strip leading # from hex color
s() { echo "${1#\#}"; }

# Helper: convert #rrggbb to "r, g, b" decimal for CSS rgba()
hex2rgb() {
    local h="${1#\#}"
    printf "%d, %d, %d" "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

# ═══════════════════════════════════════════════════════════════════
# 3. GTK CSS color sidecars (each app's style.css imports colors.css)
#
# Apps that use gtk_css_provider_load_from_path resolve @import URLs
# relative to the stylesheet's directory, so we hand them a sidecar
# colors.css next to style.css. Wofi uses load_from_data, which has no
# base path — for wofi we still inline colors via marker replacement
# (see section 3b below).
# ═══════════════════════════════════════════════════════════════════

cat > "$HOME/.config/waybar/colors.css" << EOF
@define-color bg_base ${BASE};
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
@define-color border_subtle rgba($(hex2rgb "$BORDER"), 0.6);
EOF

# 3b. Wofi: loads its CSS from memory (load_from_data), so @import has no base
#     path and colours are inlined instead: style.css is generated from the
#     tracked style.template.css by filling in the marked block. Edit the template.
WOFI_TEMPLATE="$HOME/.config/wofi/style.template.css"
WOFI_STYLE="$HOME/.config/wofi/style.css"
if [ -f "$WOFI_TEMPLATE" ]; then
    awk -v c="@define-color bg_base ${BASE};
@define-color bg_crust ${CRUST};
@define-color text_primary ${TEXT};
@define-color text_bright ${ACCENT_BRIGHT};
@define-color selection ${SELECTION};
@define-color border_color ${CRUST};" '
    /theme-colors-start/ { print; print c; skip = 1; next }
    /theme-colors-end/   { skip = 0 }
    !skip { print }
    ' "$WOFI_TEMPLATE" > "${WOFI_STYLE}.tmp" && mv "${WOFI_STYLE}.tmp" "$WOFI_STYLE"
fi

cat > "$HOME/.config/swaync/colors.css" << EOF
@define-color cc-bg ${BASE};
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
@define-color blue-base ${ACCENT};
EOF

mkdir -p "$HOME/.config/swayosd"
cat > "$HOME/.config/swayosd/colors.css" << EOF
@define-color osd_bg ${BASE};
@define-color osd_fg ${TEXT};
@define-color osd_border rgba($(hex2rgb "$BORDER"), 0.6);
@define-color osd_accent ${ACCENT};
EOF

cat > "$HOME/.config/wlogout/colors.css" << EOF
@define-color bg_base ${BASE};
@define-color selection ${SELECTION};
@define-color text_primary ${TEXT};
@define-color border_color ${BORDER};
EOF

# ═══════════════════════════════════════════════════════════════════
# 4. GTK theme "Palette": adw-gtk3 recoloured with the current palette
#
# GTK_THEME=Palette (hypr/lua/env.lua, niri/config.kdl) points every GTK3
# and GTK4 app here. Needs the adw-gtk-theme package. adw-gtk3 derives all
# of its colours from the named colours below, for GTK3 and GTK4 alike.
# GTK apps read their theme at startup, so running apps need a restart.
# ═══════════════════════════════════════════════════════════════════

# Perceived brightness (YIQ) of #rrggbb, 0-255
brightness() {
    local h="${1#\#}"
    echo $(( (299 * 16#${h:0:2} + 587 * 16#${h:2:2} + 114 * 16#${h:4:2}) / 1000 ))
}

# Light palettes (wallpaper-light) build on light adw-gtk3, dark ones on dark
# (STANDALONE: how libadwaita derives readable text from accent/status colours)
if [ "$(brightness "$BASE")" -gt 140 ]; then
    ADW="adw-gtk3";      INK_DARK="$TEXT"; INK_LIGHT="$BASE"; STANDALONE="min(l, 0.5) a b"
else
    ADW="adw-gtk3-dark"; INK_DARK="$BASE"; INK_LIGHT="$TEXT"; STANDALONE="max(l, 0.85) a b"
fi
# Readable text colour on top of the given background colour
on() { if [ "$(brightness "$1")" -gt 140 ]; then echo "$INK_DARK"; else echo "$INK_LIGHT"; fi; }

# libadwaita/GNOME apps (and LibreWolf's light/dark) follow this setting
if [ "$ADW" = "adw-gtk3" ]; then COLOR_SCHEME="prefer-light"; else COLOR_SCHEME="prefer-dark"; fi
if [ "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" != "'$COLOR_SCHEME'" ]; then
    gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME" 2>/dev/null || true
fi

GTK_PALETTE="$HOME/.local/share/themes/Palette"
if [ -d "/usr/share/themes/$ADW" ]; then
    GTK_COLORS="@define-color accent_color ${ACCENT};
@define-color accent_bg_color ${ACCENT};
@define-color accent_fg_color $(on "$ACCENT");
@define-color destructive_bg_color ${RED};
@define-color destructive_fg_color $(on "$RED");
@define-color error_bg_color ${RED};
@define-color error_fg_color $(on "$RED");
@define-color success_bg_color ${GREEN};
@define-color success_fg_color $(on "$GREEN");
@define-color warning_bg_color ${YELLOW};
@define-color warning_fg_color $(on "$YELLOW");

@define-color window_bg_color ${BASE};
@define-color window_fg_color ${TEXT};
@define-color view_bg_color ${BASE};
@define-color view_fg_color ${TEXT};
@define-color headerbar_bg_color ${MANTLE};
@define-color headerbar_fg_color ${TEXT};
@define-color headerbar_border_color ${TEXT};
@define-color headerbar_backdrop_color ${BASE};
@define-color sidebar_bg_color ${MANTLE};
@define-color sidebar_fg_color ${TEXT};
@define-color sidebar_backdrop_color ${SURFACE0};
@define-color secondary_sidebar_bg_color ${SURFACE0};
@define-color secondary_sidebar_fg_color ${TEXT};
@define-color secondary_sidebar_backdrop_color ${SURFACE0};
@define-color card_bg_color rgba($(hex2rgb "$TEXT"), 0.05);
@define-color card_fg_color ${TEXT};
@define-color dialog_bg_color ${SURFACE1};
@define-color dialog_fg_color ${TEXT};
@define-color popover_bg_color ${SURFACE1};
@define-color popover_fg_color ${TEXT};
@define-color thumbnail_bg_color ${SURFACE1};
@define-color thumbnail_fg_color ${TEXT};"

    mkdir -p "$GTK_PALETTE/gtk-3.0" "$GTK_PALETTE/gtk-4.0"
    cat > "$GTK_PALETTE/gtk-3.0/gtk.css" << EOF
/* Auto-generated by theme_apply.sh: ${ADW} recoloured with the current palette */
@import url("file:///usr/share/themes/${ADW}/gtk-3.0/gtk.css");

${GTK_COLORS}

/* Lutris: tint the selected sidebar row with the accent */
.lutris-sidebar row:selected,
.lutris-sidebar row:selected:hover,
.lutris-sidebar row:selected:active,
.lutris-sidebar row:selected:backdrop {
    background-color: alpha(@accent_bg_color, 0.16);
    color: @accent_color;
}
.lutris-sidebar row:selected image { color: @accent_color; }
EOF
    cat > "$GTK_PALETTE/gtk-4.0/gtk.css" << EOF
/* Auto-generated by theme_apply.sh: ${ADW} recoloured with the current palette */
@import url("file:///usr/share/themes/${ADW}/gtk-4.0/gtk.css");

${GTK_COLORS}

/* adw-gtk3's libadwaita-tweaks.css pins the accent to blue; use the palette's.
   Plain GTK4 apps may not report dark mode, so the light/dark text formula
   follows the palette instead of prefers-color-scheme. */
:root {
    --accent-bg-color: @accent_bg_color;
    --accent-fg-color: @accent_fg_color;
    --standalone-color-oklab: ${STANDALONE};
}
EOF
    for v in gtk-3.0 gtk-4.0; do
        cp "$GTK_PALETTE/$v/gtk.css" "$GTK_PALETTE/$v/gtk-dark.css"
    done
    printf '[Desktop Entry]\nType=X-GNOME-Metatheme\nName=Palette\nComment=adw-gtk3 recoloured by theme_apply.sh\n\n[X-GNOME-Metatheme]\nGtkTheme=Palette\n' \
        > "$GTK_PALETTE/index.theme"
else
    echo "theme_apply.sh: /usr/share/themes/$ADW not found (install adw-gtk-theme), skipping GTK theme" >&2
fi

# ═══════════════════════════════════════════════════════════════════
# 4b. Icon theme "Palette": Adwaita with folders in the accent colour
#     (running GTK apps pick it up through the settings flip in section 10)
# ═══════════════════════════════════════════════════════════════════
if [ -d /usr/share/icons/Adwaita/scalable/places ]; then
    python3 "$HOME/.config/scripts/desktop/folder_icons.py" "$ACCENT" "$HOME/.local/share/icons/Palette"
else
    echo "theme_apply.sh: Adwaita icons not found, skipping folder icons" >&2
fi

# ═══════════════════════════════════════════════════════════════════
# 4c. Qt apps: qt6ct colour scheme "Palette" on the Fusion style, plus a KDE
#     colour scheme for KDE apps (Kdenlive: Settings → Colour Theme → Palette).
#     QT_QPA_PLATFORMTHEME=qt6ct comes from hypr/lua/env.lua. Qt apps read
#     colours at startup only, so running ones need a restart.
# ═══════════════════════════════════════════════════════════════════
QT6CT_DIR="$HOME/.config/qt6ct"
mkdir -p "$QT6CT_DIR/colors"

# Dark palettes put entries/lists (Base) a step darker than the window; light
# ones a step lighter, as GTK does.
if [ "$ADW" = "adw-gtk3" ]; then QT_WINDOW="$MANTLE"; QT_BASE="$BASE"; else QT_WINDOW="$BASE"; QT_BASE="$MANTLE"; fi
qt_roles() { # $1 text colour, $2 highlight, $3 highlighted text
    # QPalette role order: WindowText Button Light Midlight Dark Mid Text
    # BrightText ButtonText Base Window Shadow Highlight HighlightedText Link
    # LinkVisited AlternateBase NoRole ToolTipBase ToolTipText PlaceholderText Accent
    local c=("$1" "$SURFACE0" "$SURFACE2" "$SURFACE1" "$CRUST" "$MANTLE" "$1"
             "$QT_WINDOW" "$1" "$QT_BASE" "$QT_WINDOW" "$CRUST" "$2" "$3" "$ACCENT"
             "$MAUVE" "$QT_WINDOW" "$QT_WINDOW" "$SURFACE1" "$TEXT" "$SUBTEXT1" "$ACCENT")
    local IFS=,
    echo "${c[*]/#\#/#ff}" | sed 's/,/, /g'
}
cat > "$QT6CT_DIR/colors/Palette.conf" << EOF
[ColorScheme]
active_colors=$(qt_roles "$TEXT" "$ACCENT" "$(on "$ACCENT")")
inactive_colors=$(qt_roles "$TEXT" "$ACCENT" "$(on "$ACCENT")")
disabled_colors=$(qt_roles "$SUBTEXT1" "$SURFACE2" "$SUBTEXT1")
EOF

# Point qt6ct at it and use the GTK fonts, keeping any other settings made in
# the qt6ct app
GTK_FONT=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null | tr -d "'")
GTK_MONO=$(gsettings get org.gnome.desktop.interface monospace-font-name 2>/dev/null | tr -d "'")
python3 - "$QT6CT_DIR/qt6ct.conf" "$QT6CT_DIR/colors/Palette.conf" "${GTK_FONT:-Cantarell 11}" "${GTK_MONO:-Monospace 10}" << 'PYEOF'
import configparser, sys
path, scheme, font, mono = sys.argv[1:5]
def qfont(spec):  # "Family Name 11" -> QFont::toString() as qt6ct stores it
    family, _, size = spec.rpartition(" ")
    return f'"{family},{size},-1,5,400,0,0,0,0,0,0,0,0,0,0,1"'
c = configparser.ConfigParser(interpolation=None)
c.optionxform = str
c.read(path)
for section in ("Appearance", "Fonts"):
    if not c.has_section(section):
        c.add_section(section)
c["Appearance"].update({"color_scheme_path": scheme, "custom_palette": "true",
                        "icon_theme": "Palette", "style": "Fusion",
                        "standard_dialogs": "xdgdesktopportal"})
c["Fonts"].update({"general": qfont(font), "fixed": qfont(mono)})
with open(path, "w") as f:
    c.write(f, space_around_delimiters=False)
PYEOF

kde() { local h="${1#\#}"; printf '%d,%d,%d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"; }
kde_set() { # $1 section, $2 background, $3 alternate background, $4 text
    cat << EOF
[Colors:$1]
BackgroundAlternate=$(kde "$3")
BackgroundNormal=$(kde "$2")
DecorationFocus=$(kde "$ACCENT")
DecorationHover=$(kde "$ACCENT")
ForegroundActive=$(kde "$ACCENT")
ForegroundInactive=$(kde "$SUBTEXT0")
ForegroundLink=$(kde "$ACCENT")
ForegroundNegative=$(kde "$RED")
ForegroundNeutral=$(kde "$YELLOW")
ForegroundNormal=$(kde "$4")
ForegroundPositive=$(kde "$GREEN")
ForegroundVisited=$(kde "$MAUVE")

EOF
}
mkdir -p "$HOME/.local/share/color-schemes"
{
    echo "[General]"
    echo "ColorScheme=Palette"
    echo "Name=Palette"
    echo
    kde_set Window "$QT_WINDOW" "$SURFACE0" "$TEXT"
    kde_set View "$QT_BASE" "$QT_WINDOW" "$TEXT"
    kde_set Button "$SURFACE0" "$SURFACE1" "$TEXT"
    kde_set Selection "$ACCENT" "$ACCENT" "$(on "$ACCENT")"
    kde_set Tooltip "$SURFACE1" "$SURFACE0" "$TEXT"
    kde_set Complementary "$MANTLE" "$CRUST" "$TEXT"
    kde_set Header "$MANTLE" "$CRUST" "$TEXT"
    echo "[WM]"
    echo "activeBackground=$(kde "$MANTLE")"
    echo "activeForeground=$(kde "$TEXT")"
    echo "inactiveBackground=$(kde "$CRUST")"
    echo "inactiveForeground=$(kde "$SUBTEXT0")"
} > "$HOME/.local/share/color-schemes/Palette.colors"

# ═══════════════════════════════════════════════════════════════════
# 5. Hyprland colors.lua (require()d by lua/theme.lua)
# ═══════════════════════════════════════════════════════════════════
cat > "$HOME/.config/hypr/colors.lua" << EOF
-- Auto-generated by theme_apply.sh — do not edit manually
return {
    bg              = "rgb($(s "$BASE"))",
    mantle          = "rgb($(s "$MANTLE"))",
    crust           = "rgb($(s "$CRUST"))",
    surface0        = "rgb($(s "$SURFACE0"))",
    surface1        = "rgb($(s "$SURFACE1"))",
    text            = "rgb($(s "$TEXT"))",
    accent          = "rgb($(s "$ACCENT"))",
    border          = "rgba($(s "$BORDER")aa)",
    border_inactive = "rgba($(s "$CRUST")66)",
    red             = "rgb($(s "$RED"))",
    green           = "rgb($(s "$GREEN"))",
    yellow          = "rgb($(s "$YELLOW"))",
    blue            = "rgb($(s "$BLUE"))",
    mauve           = "rgb($(s "$MAUVE"))",
    rounding        = ${RAD_L},
}
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
# 8. Ghostty colors (sidecar included from main config via config-file)
# ═══════════════════════════════════════════════════════════════════
mkdir -p "$HOME/.config/ghostty"
cat > "$HOME/.config/ghostty/colors" << EOF
background = $(s "$BASE")
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
palette = 15=$(s "$TBW")
EOF

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
# 10. Reload applications
# ═══════════════════════════════════════════════════════════════════
if [ "$skip_reload" != "--no-reload" ]; then
    # Ghostty (reload via DBus)
    busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate "sava{sv}" "reload-config" 0 0 2>/dev/null || true

    # Waybar: reload config and CSS in place
    if pgrep -x waybar >/dev/null; then
        killall -SIGUSR2 waybar 2>/dev/null || true
    else
        waybar > /dev/null 2>&1 &
        disown
    fi

    # SwayNC: reload CSS in place (a restart would drop notification history
    # and do-not-disturb)
    if pgrep -x swaync >/dev/null; then
        swaync-client --reload-css > /dev/null 2>&1 || true
    else
        swaync > /dev/null 2>&1 &
        disown
    fi

    # Hyprland reloads config including colors.lua; niri reloads by itself
    reload_compositor

    # CAVA (rebuild config from base + generated colors)
    if [ -f "$HOME/.config/cava/config_base" ] && [ -f "$HOME/.config/cava/colors" ]; then
        cat "$HOME/.config/cava/config_base" "$HOME/.config/cava/colors" > "$HOME/.config/cava/config" 2>/dev/null
        pgrep -x cava >/dev/null && killall -USR1 cava 2>/dev/null || true
    fi

    # SwayOSD only reads its stylesheet at startup
    if pgrep -x swayosd-server >/dev/null 2>&1; then
        killall swayosd-server 2>/dev/null || true
        swayosd-server > /dev/null 2>&1 &
        disown
    fi

    # Running GTK apps (Nautilus, Lutris, ...) only re-read the Palette theme and
    # folder icons from disk when these settings change, so flip them away and
    # back. Apps started with GTK_THEME=Palette stay on Palette throughout.
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme 'Adwaita' 2>/dev/null || true
    sleep 0.3
    gsettings set org.gnome.desktop.interface gtk-theme 'Palette' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme 'Palette' 2>/dev/null || true

    notify-send -a "Theme" "Theme Applied" "$(cat "$STATE_FILE" 2>/dev/null || echo "$mode")" 2>/dev/null || true
fi
