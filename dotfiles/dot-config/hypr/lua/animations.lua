-- Animation curves and tree.
-- Ported from animations.conf.

hl.curve("wind",   { type = "bezier", points = { { 0.1, 0.9 },  { 0.1, 1 } } })  -- small overshoot on standard animation
hl.curve("winIn",  { type = "bezier", points = { { 0.1, 1.05 }, { 0.1, 1 } } })  -- minor overshoot for entry
hl.curve("winOut", { type = "bezier", points = { { 0.3, 0.2 },  { 0.05, 1 } } }) -- smooth, no overshoot on exit
hl.curve("liner",  { type = "bezier", points = { { 1, 1 },      { 1, 1 } } })    -- linear, for steady animations

hl.config({ animations = { enabled = true } })

hl.animation({ leaf = "windows",     enabled = true, speed = 4,   bezier = "wind",   style = "slide" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4,   bezier = "winIn",  style = "slide" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 4,   bezier = "winOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4,   bezier = "wind",   style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 1,   bezier = "liner" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "liner",  style = "loop" })
hl.animation({ leaf = "fade",        enabled = true, speed = 7,   bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4,   bezier = "wind" })
