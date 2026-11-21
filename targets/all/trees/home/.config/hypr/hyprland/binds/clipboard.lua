local bind = require("lib.bind")

bind.bind("SUPER + C", hl.dsp.send_shortcut({ mods = "CTRL", key = "Insert" }), "Universal copy")
bind.bind("SUPER + V", hl.dsp.send_shortcut({ mods = "SHIFT", key = "Insert" }), "Universal paste")
bind.bind("SUPER + X", hl.dsp.send_shortcut({ mods = "CTRL", key = "X" }), "Universal cut")
bind.exec("SUPER + CTRL + V", "Clipboard manager", "walker -m clipboard")
