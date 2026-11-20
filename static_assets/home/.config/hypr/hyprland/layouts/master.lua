local bind = require("lib.bind")

hl.config({
    master = {
        allow_small_split = false,
        mfact = 0.55,
        new_status = "master",
        new_on_top = false,
        new_on_active = "none",
        orientation = "left",
        slave_count_for_center_master = 2,
        center_master_fallback = "left",
        smart_resizing = true,
        drop_at_cursor = true,
        always_keep_position = false,
    },
})

bind.bind("SUPER + CTRL + ALT + M", hl.dsp.layout("swapwithmaster master"), "Master: swap focused window with master")
bind.bind("SUPER + CTRL + ALT + F", hl.dsp.layout("focusmaster"), "Master: focus master window")

bind.bind("SUPER + CTRL + ALT + N", hl.dsp.layout("cyclenext"), "Master: focus next window")
bind.bind("SUPER + CTRL + ALT + P", hl.dsp.layout("cycleprev"), "Master: focus previous window")
bind.bind("SUPER + CTRL + ALT + SHIFT + N", hl.dsp.layout("swapnext"), "Master: swap with next window")
bind.bind("SUPER + CTRL + ALT + SHIFT + P", hl.dsp.layout("swapprev"), "Master: swap with previous window")

bind.bind("SUPER + CTRL + ALT + A", hl.dsp.layout("addmaster"), "Master: add master window")
bind.bind("SUPER + CTRL + ALT + D", hl.dsp.layout("removemaster"), "Master: remove master window")

bind.bind("SUPER + CTRL + ALT + H", hl.dsp.layout("orientationleft"), "Master: orient left")
bind.bind("SUPER + CTRL + ALT + L", hl.dsp.layout("orientationright"), "Master: orient right")
bind.bind("SUPER + CTRL + ALT + K", hl.dsp.layout("orientationtop"), "Master: orient top")
bind.bind("SUPER + CTRL + ALT + J", hl.dsp.layout("orientationbottom"), "Master: orient bottom")
bind.bind("SUPER + CTRL + ALT + C", hl.dsp.layout("orientationcenter"), "Master: orient center")
bind.bind("SUPER + CTRL + ALT + O", hl.dsp.layout("orientationnext"), "Master: next orientation")
bind.bind("SUPER + CTRL + ALT + SHIFT + O", hl.dsp.layout("orientationprev"), "Master: previous orientation")
bind.bind(
    "SUPER + CTRL + ALT + SHIFT + C",
    hl.dsp.layout("orientationcycle left top right bottom center"),
    "Master: cycle configured orientations"
)

bind.bind("SUPER + CTRL + ALT + X", hl.dsp.layout("mfact -0.05"), "Master: shrink master area")
bind.bind("SUPER + CTRL + ALT + SHIFT + X", hl.dsp.layout("mfact +0.05"), "Master: grow master area")
bind.bind("SUPER + CTRL + ALT + SHIFT + M", hl.dsp.layout("mfact exact 0.55"), "Master: reset master area")

bind.bind("SUPER + CTRL + ALT + R", hl.dsp.layout("rollnext"), "Master: roll next into master")
bind.bind("SUPER + CTRL + ALT + SHIFT + R", hl.dsp.layout("rollprev"), "Master: roll previous into master")
