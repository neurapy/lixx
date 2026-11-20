local bind = require("lib.bind")

bind.bind("SUPER + C", hl.dsp.send_shortcut({ mods = "CTRL", key = "Insert" }), "Universal copy")
bind.bind("SUPER + V", hl.dsp.send_shortcut({ mods = "SHIFT", key = "Insert" }), "Universal paste")
bind.bind("SUPER + X", hl.dsp.send_shortcut({ mods = "CTRL", key = "X" }), "Universal cut")
bind.optional_exec("SUPER + CTRL + V", "Clipboard manager", "omarchy-launch-walker -m clipboard")
