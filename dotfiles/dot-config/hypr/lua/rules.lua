-- Window and layer rules.
-- Ported from windowrules.conf.
--
-- hyprlang percentages become monitor-relative expressions:
--   move 69.5% 55%  ->  move = { "monitor_w*0.695", "monitor_h*0.55" }
--   size 30% 40%    ->  size = { "monitor_w*0.3",   "monitor_h*0.4"  }

-- Mullvad VPN: small floating panel, bottom right.
hl.window_rule({
    name  = "mullvad",
    match = { class = "mullvad-vpn" },
    float = true,
    move  = { "monitor_w*0.695", "monitor_h*0.55" },
    size  = { "monitor_w*0.3", "monitor_h*0.4" },
})

-- pavucontrol: same placement as mullvad.
hl.window_rule({
    name  = "pavucontrol",
    match = { class = "pavucontrol" },
    float = true,
    move  = { "monitor_w*0.695", "monitor_h*0.55" },
    size  = { "monitor_w*0.3", "monitor_h*0.4" },
})

-- pulsemixer, launched in a terminal titled "Volume".
-- (The old config tried `match:namespace Volume`, which is a *layer* prop, and
--  then pasted the mullvad move/size lines underneath it by mistake.)
hl.window_rule({
    name         = "pulsemixer",
    match        = { title = "^(Volume)$" },
    float        = true,
    center       = true,
    size         = { "monitor_w*0.3", "monitor_h*0.4" },
    border_color = "rgba(185ac4ff) rgba(185ac4ff)",
})

hl.window_rule({
    name  = "brave-tiled",
    match = { class = "Brave-browser" },
    tile  = true,
})

hl.window_rule({
    name   = "thunar",
    match  = { class = "thunar" },
    float  = true,
    center = true,
    size   = { "monitor_w*0.5", "monitor_h*0.5" },
})

hl.window_rule({
    name   = "badlion",
    match  = { class = "BadlionClient" },
    float  = true,
    center = true,
    size   = { "monitor_w*0.5", "monitor_h*0.5" },
})

hl.window_rule({
    name    = "discord",
    match   = { initial_title = "discord" },
    float   = true,
    center  = true,
    size    = { "monitor_w*0.5", "monitor_h*0.5" },
    monitor = "DP-2",
})

-- Brave's Google login popup.
hl.window_rule({
    name   = "brave-login-popup",
    match  = { initial_title = "Untitled - Brave" },
    float  = true,
    center = true,
    size   = { "monitor_w*0.5", "monitor_h*0.5" },
})

-- librepods autostarts with --hide, but if its window does show up it should
-- not steal focus or a tile.
hl.window_rule({
    name             = "librepods",
    match            = { class = "me.kavishdevar.librepods" },
    float            = true,
    center           = true,
    size             = { "monitor_w*0.35", "monitor_h*0.6" },
    no_initial_focus = true,
})

hl.layer_rule({
    name  = "blur-logout",
    match = { namespace = "logout_dialog" },
    blur  = true,
})
