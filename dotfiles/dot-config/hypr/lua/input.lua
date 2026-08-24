-- Keyboard, mouse, touchpad, gestures.
-- Ported from the input{} / device{} / gestures{} blocks.
--
-- Two layouts are declared so switch_layout.sh can flip between them with
-- `hyprctl switchxkblayout` instead of sed-editing this file at runtime.
-- `us` stays first so keybinds resolve against it.

hl.config({
    input = {
        kb_layout  = "us,no",
        kb_variant = "altgr-intl,",
        kb_model   = "",
        kb_options = "lv3:caps_switch",
        kb_rules   = "",

        follow_mouse   = 1,
        force_no_accel = true,
        sensitivity    = -0.35, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll       = true,
            disable_while_typing = false,
            scroll_factor        = 0.8,
        },
    },

    gestures = {
        workspace_swipe_forever = true,
    },
})

hl.device({
    name        = "elan1201:00-04f3:3098-touchpad",
    sensitivity = 0.1,
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
