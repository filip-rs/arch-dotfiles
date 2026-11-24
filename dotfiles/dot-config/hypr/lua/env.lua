-- Environment variables and XWayland.
-- Ported from hyprland.conf (env = ... / xwayland { ... }).

hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Terminal for Super + Q / Caps + Q. Swap alacritty <-> ghostty here.
hl.env("TERMINAL", "alacritty")

hl.env("GTK_THEME", "Palette") -- adw-gtk3 recoloured by scripts/desktop/theme_apply.sh
hl.env("WALLPAPER_DIR", "~/Pictures/Wallpapers")
hl.env("SCRIPT_DIR", "~/.config/scripts/desktop")

hl.env("GDK_SCALE", "1")
hl.env("GDK_DPI_SCALE", "1")
hl.env("XCURSOR_SIZE", "21")

-- Qt apps: Fusion + the "Palette" colour scheme written by theme_apply.sh.
-- Quickshell is started without it (autostart.lua, qs_manager.sh, lock.sh) so
-- its hand-styled panels and lockscreen are unaffected.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- ...which also means Quickshell doesn't get qt6ct's icon theme. Without this
-- it only searches hicolor, and launcher entries with generic Adwaita icons
-- (ranger, Qt6 Settings, Monitor Settings) fall back to letters.
hl.env("QS_ICON_THEME", "Palette")

-- unscale XWayland
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})
