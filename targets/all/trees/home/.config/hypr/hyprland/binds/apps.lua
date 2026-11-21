local bind = require("lib.bind")

bind.exec("SUPER + RETURN", "Terminal", "uwsm-app -- ghostty +new-window")
bind.exec("SUPER + CTRL + RETURN", "Terminal in active cwd", "lixx-terminal")
bind.exec("SUPER + SHIFT + B", "Web browser", bind.available("firefox") and "uwsm-app -- firefox" or "uwsm-app -- epiphany")
bind.exec("SUPER + SHIFT + F", "File manager", "uwsm-app -- nautilus --new-window")
if bind.available("obsidian") then
    bind.exec("SUPER + SHIFT + O", "Obsidian", "lixx-menu obsidian")
end
