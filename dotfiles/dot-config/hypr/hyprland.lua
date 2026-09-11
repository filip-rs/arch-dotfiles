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
-- The old hyprlang config (hyprland.conf and friends) has been removed; it
-- lives in git history if it is ever needed again.

require("lua.env")
require("lua.theme")
require("lua.monitors")
require("lua.looknfeel")
require("lua.animations")
require("lua.input")
require("lua.rules")
require("lua.binds")
require("lua.plugins")
require("lua.autostart")
