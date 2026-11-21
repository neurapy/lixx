local bind = require("lib.bind")
local windows = require("lib.windows")

bind.bind("SUPER + H", hl.dsp.focus({ direction = "l" }))
bind.bind("SUPER + J", hl.dsp.focus({ direction = "d" }))
bind.bind("SUPER + K", hl.dsp.focus({ direction = "u" }))
bind.bind("SUPER + L", hl.dsp.focus({ direction = "r" }))

bind.bind("SUPER + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
bind.bind("SUPER + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
bind.bind("SUPER + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
bind.bind("SUPER + SHIFT + L", hl.dsp.window.move({ direction = "r" }))

bind.bind("SUPER + mouse:272", hl.dsp.window.drag(), "Move window", { mouse = true })
bind.bind("SUPER + mouse:273", hl.dsp.window.resize(), "Resize window", { mouse = true })

bind.bind("SUPER + CTRL + SHIFT + h", hl.dsp.window.swap({ direction = "l" }))
bind.bind("SUPER + CTRL + SHIFT + j", hl.dsp.window.swap({ direction = "d" }))
bind.bind("SUPER + CTRL + SHIFT + k", hl.dsp.window.swap({ direction = "u" }))
bind.bind("SUPER + CTRL + SHIFT + l", hl.dsp.window.swap({ direction = "r" }))

bind.bind("SUPER + CTRL + H", bind.resize_active_by_monitor_ratio(-0.05, 0), "Resize window left", { repeating = true })
bind.bind("SUPER + CTRL + J", bind.resize_active_by_monitor_ratio(0, 0.05), "Resize window down", { repeating = true })
bind.bind("SUPER + CTRL + K", bind.resize_active_by_monitor_ratio(0, -0.05), "Resize window up", { repeating = true })
bind.bind("SUPER + CTRL + L", bind.resize_active_by_monitor_ratio(0.05, 0), "Resize window right", { repeating = true })

bind.bind("SUPER + W", hl.dsp.window.close(), "Close window")
bind.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), "Full screen")
bind.bind("SUPER + CTRL + F", hl.dsp.window.fullscreen_state({ internal = 0, client = 2 }), "Tiled full screen")
bind.bind("SUPER + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }), "Full width")
bind.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }), "Toggle window floating/tiling")
bind.bind("SUPER + O", windows.pop, "Pop window out (float & pin)")
bind.bind("SUPER + P", hl.dsp.window.pseudo(), "Pseudo window")
bind.bind("CTRL + ALT + DELETE", windows.close_all, "Close all windows")

for i = 1, 10 do
    local keycode = i + 9
    bind.bind("SUPER + code:" .. keycode, hl.dsp.focus({ workspace = i }), "Switch to workspace " .. i)
    bind.bind(
        "SUPER + SHIFT + code:" .. keycode,
        hl.dsp.window.move({ workspace = i }),
        "Move window to workspace " .. i
    )
    bind.bind(
        "SUPER + SHIFT + ALT + code:" .. keycode,
        hl.dsp.window.move({ workspace = i, follow = false }),
        "Move window silently to workspace " .. i
    )
end

bind.bind("SUPER + TAB", hl.dsp.focus({ workspace = "e+1" }), "Next workspace")

bind.bind("SUPER + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }), "Previous workspace")
bind.bind("SUPER + CTRL + TAB", hl.dsp.focus({ workspace = "previous" }), "Former workspace")

bind.bind("SUPER + E", hl.dsp.workspace.toggle_special("termispace"))
bind.bind("SUPER + grave", hl.dsp.workspace.toggle_special("slackspace"))
bind.bind("SUPER + S", hl.dsp.workspace.toggle_special("scratchpad"), "Toggle scratchpad")
bind.bind(
    "SUPER + SHIFT + S",
    hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }),
    "Move window to scratchpad"
)

bind.bind("SUPER + G", hl.dsp.group.toggle(), "Toggle window grouping")
bind.bind("SUPER + ALT + G", hl.dsp.window.move({ out_of_group = true }), "Move active window out of group")
bind.bind("SUPER + ALT + LEFT", hl.dsp.window.move({ into_group = "l" }), "Move window to group on left")
bind.bind("SUPER + ALT + RIGHT", hl.dsp.window.move({ into_group = "r" }), "Move window to group on right")
bind.bind("SUPER + ALT + UP", hl.dsp.window.move({ into_group = "u" }), "Move window to group on top")
bind.bind("SUPER + ALT + DOWN", hl.dsp.window.move({ into_group = "d" }), "Move window to group on bottom")
bind.bind("SUPER + ALT + TAB", hl.dsp.group.next(), "Next window in group")
bind.bind("SUPER + ALT + SHIFT + TAB", hl.dsp.group.prev(), "Previous window in group")
bind.bind("SUPER + CTRL + LEFT", hl.dsp.group.prev(), "Move grouped window focus left")
bind.bind("SUPER + CTRL + RIGHT", hl.dsp.group.next(), "Move grouped window focus right")
bind.bind("SUPER + ALT + mouse_down", hl.dsp.group.next(), "Next window in group")
bind.bind("SUPER + ALT + mouse_up", hl.dsp.group.prev(), "Previous window in group")

for i = 1, 5 do
    bind.bind("SUPER + ALT + code:" .. (i + 9), hl.dsp.group.active({ index = i }), "Switch to group window " .. i)
end

bind.bind("SUPER + Slash", windows.scale, "Cycle monitor scaling")
