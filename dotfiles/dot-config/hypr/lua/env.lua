-- Environment variables and XWayland.
-- Ported from hyprland.conf (env = ... / xwayland { ... }).

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

-- unscale XWayland
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})
