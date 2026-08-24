--       ░▒▒▒▒▒▒▒░░░
--     ░░▒▒▒▒▒▒░░░░▓▓
--    ░░▒▒▒▒▒░░░░░▓▓
--   ░░░▒▒▒░░░░░░▓▓
--   ░░░▒▒▒░░░░░▓▓▓▓▓▓
--    ░░░▒▒░░░░▓▓   ▓▓
--     ░░░▒▒░░▓▓   ▓▓
--       ░░▒▒▓▓   ▓▓ YPRLAND config  (Lua, 0.55+)
--
-- Split across lua/*.lua. Each require() is its own scope, so an error in one
-- file does not take the rest of the config down with it.
--
-- The old hyprlang config is still on disk (hyprland.conf and friends).
-- Hyprland ignores it while this file exists, so
--     mv ~/.config/hypr/hyprland.lua{,.off}
-- is a complete rollback.

require("lua.env")
require("lua.theme")
require("lua.monitors")
require("lua.looknfeel")
require("lua.animations")
require("lua.input")
require("lua.rules")
require("lua.binds")
require("lua.autostart")
