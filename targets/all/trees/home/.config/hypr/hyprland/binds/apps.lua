local bind = require("lib.bind")
local ghostty = "uwsm app -- ghostty"

bind.exec("SUPER + RETURN", "Terminal", ghostty)
if bind.available("omarchy-cmd-terminal-cwd") then
    bind.exec("SUPER + CTRL + RETURN", "Terminal in active cwd",
        ghostty .. [[ --working-directory="$(omarchy-cmd-terminal-cwd)"]])
else
    bind.exec("SUPER + CTRL + RETURN", "Terminal in active cwd", ghostty .. " +new-window")
end
if bind.available("firefox") then
    bind.exec("SUPER + SHIFT + B", "Firefox", "uwsm app -- firefox")
end
if bind.available("nautilus") then
    bind.exec("SUPER + SHIFT + F", "File manager", "uwsm app -- nautilus --new-window")
end
if bind.available("obsidian") then
    bind.exec("SUPER + SHIFT + O", "Obsidian", "uwsm app -- obsidian --disable-gpu --enable-wayland-ime")
end
