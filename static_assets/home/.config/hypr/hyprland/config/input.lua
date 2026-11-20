hl.config({
    input = {
        kb_model = "pc105",
        kb_layout = "de",
        kb_variant = "us",
        kb_options = "compose:caps",
        numlock_by_default = true,
        repeat_rate = 30,
        repeat_delay = 300,
        sensitivity = 0.0,
        follow_mouse = 1,

        touchpad = {
            disable_while_typing = false,
            natural_scroll = true,
            scroll_factor = 0.4,
        },
    },

    gestures = {
        workspace_swipe_distance = 350,
        workspace_swipe_min_speed_to_force = 25,
        workspace_swipe_cancel_ratio = 0.25,
        workspace_swipe_create_new = true,
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})
