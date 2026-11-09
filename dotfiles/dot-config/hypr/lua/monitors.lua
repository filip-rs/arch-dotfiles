-- Monitors.
--
-- Per-machine monitor lines live in host.lua (gitignored, written by
-- scripts/desktop/monitor_apply.sh), loaded at the end of this file; see
-- host.lua.example. Other per-machine settings (workspace pinning, the HDMI
-- mirror, hardware keys) are tracked in hosts/<hostname>.lua.

-- Fallback for any monitor without an explicit rule: preferred mode, placed to
-- the right of the others.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- This machine's monitor layout.
pcall(require, "host")
