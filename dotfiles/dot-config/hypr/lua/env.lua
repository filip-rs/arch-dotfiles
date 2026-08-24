-- Environment variables and XWayland.
-- Ported from hyprland.conf (env = ... / xwayland { ... }).

hl.env("GTK_THEME", "Orchis-Dark-Compact")
hl.env("WALLPAPER_DIR", "~/Pictures/Wallpapers")
hl.env("SCRIPT_DIR", "~/.config/hypr/scripts")

hl.env("GDK_SCALE", "1")
hl.env("GDK_DPI_SCALE", "1")
hl.env("XCURSOR_SIZE", "21")

-- env = QT_QPA_PLATFORMTHEME,qt6ct   -- for Qt apps
-- env = QT_STYLE_OVERRIDE,Breeze

-- unscale XWayland
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})
