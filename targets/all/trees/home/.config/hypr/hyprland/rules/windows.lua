local rule = require("lib.rule")

rule.window({
    {
        name = "termispace-move-non-terminal",
        match = {
            workspace = "special:termispace",
            initial_title = "negative:^(termispace-win)$",
        },
        workspace = "+0",
    },
    {
        name = "termispace-fullscreen",
        match = {
            initial_title = "^(termispace-win)$",
        },
        fullscreen = true,
        no_blur = true,
        animation = "popin",
    },
    {
        name = "slackspace-move-non-slack",
        match = {
            workspace = "special:slackspace",
            class = "negative:^([Ss]lack|hyprland-share-picker)$",
        },
        workspace = "+0",
    },
    {
        name = "slackspace-fullscreen",
        match = {
            workspace = "special:slackspace",
            class = "^([Ss]lack)$",
        },
        fullscreen = true,
        opacity = "1.0 override 1.0 override 0.87 override",
    },
    {
        name = "scratchpad-opacity",
        match = { workspace = "special:scratchpad" },
        opacity = "0.7 override 0.7 override 0.7 override",
    },
    {
        name = "suppress-maximize-events",
        match = { class = ".*" },
        suppress_event = "maximize",
    },
    {
        name = "fix-xwayland-drags",
        match = {
            class = "^$",
            title = "^$",
            xwayland = true,
            float = true,
            fullscreen = false,
            pin = false,
        },
        no_focus = true,
    },
})
