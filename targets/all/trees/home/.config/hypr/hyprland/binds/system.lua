local bind = require("lib.bind")

bind.exec("SUPER + SPACE", "Launch apps", bind.available("omarchy-launch-walker") and "omarchy-launch-walker" or "fuzzel --launch-prefix='uwsm-app --'")
bind.exec("SUPER + SHIFT + E", "End session", "uwsm stop")
bind.optional_exec("SUPER + CTRL + E", "Emoji picker", "omarchy-launch-walker -m symbols")
bind.optional_exec("SUPER + CTRL + C", "Capture menu", "omarchy-menu capture")
bind.optional_exec("SUPER + CTRL + O", "Toggle menu", "omarchy-menu toggle")
bind.exec("SUPER + ALT + SPACE", "Desktop menu", bind.available("omarchy-menu") and "omarchy-menu" or "fuzzel --launch-prefix='uwsm-app --'")
bind.optional_exec("SUPER + ESCAPE", "System menu", "omarchy-menu system")
bind.optional_exec("XF86PowerOff", "Power menu", "omarchy-menu system", { locked = true })
bind.optional_exec("SUPER + SHIFT + Slash", "Show key bindings", "omarchy-menu-keybindings")
bind.optional_exec("XF86Calculator", "Calculator", "gnome-calculator")

bind.exec("SUPER + SHIFT + SPACE", "Toggle top bar", "systemctl --user kill -s USR1 lixx-waybar.service")
bind.optional_exec("SUPER + CTRL + SPACE", "Theme background menu", "omarchy-menu background")
bind.optional_exec("SUPER + SHIFT + CTRL + SPACE", "Theme menu", "omarchy-menu theme")
bind.bind(
    "SUPER + BACKSPACE",
    hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" }),
    "Toggle window transparency"
)
bind.optional_exec("SUPER + SHIFT + BACKSPACE", "Toggle window gaps", "omarchy-hyprland-window-gaps-toggle")
bind.optional_exec(
    "SUPER + CTRL + BACKSPACE",
    "Toggle single-window square aspect",
    "omarchy-hyprland-window-single-square-aspect-toggle"
)

bind.exec("SUPER + COMMA", "Dismiss last notification", "swaync-client --close-latest")
bind.exec("SUPER + SHIFT + COMMA", "Dismiss all notifications", "swaync-client --close-all")
bind.exec("SUPER + CTRL + COMMA", "Toggle silencing notifications", "swaync-client --toggle-dnd")

bind.exec("SUPER + CTRL + I", "Toggle locking on idle", [[$HOME/.local/bin/lixx-idle toggle]])
bind.exec("SUPER + CTRL + N", "Toggle nightlight", [[sh -c 'if systemctl --user is-active --quiet hyprsunset.service; then systemctl --user stop hyprsunset.service; else systemctl --user start hyprsunset.service; fi']])

bind.exec("PRINT", "Screenshot", [[sh -c 'region=$(slurp) && grim -g "$region" - | wl-copy --type image/png']])
bind.optional_exec("ALT + PRINT", "Screenrecording", "omarchy-menu screenrecord")
bind.exec("SUPER + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")

bind.optional_exec("SUPER + CTRL + S", "Share", "omarchy-menu share")
bind.exec("SUPER + CTRL + ALT + T", "Show time", [[notify-send "$(date +"%A %H:%M -- %d %B W%V %Y")"]])
bind.exec("SUPER + CTRL + ALT + B", "Show battery remaining", [[notify-send Battery "$(upower -i /org/freedesktop/UPower/devices/DisplayDevice)"]])

bind.exec("SUPER + CTRL + A", "Audio controls", "pavucontrol")
bind.exec("SUPER + CTRL + B", "Bluetooth controls", "ghostty -e bluetoothctl")
bind.exec("SUPER + CTRL + W", "Wifi controls", "ghostty -e nmtui")
bind.exec("SUPER + CTRL + T", "Activity", "ghostty -e btop")

bind.optional_exec("SUPER + CTRL + X", "Toggle dictation", "voxtype record toggle")
bind.bind("SUPER + CTRL + Z", function()
    hl.config({ cursor = { zoom_factor = hl.get_config("cursor.zoom_factor") + 1 } })
end, "Zoom in")
bind.bind("SUPER + CTRL + ALT + Z", function()
    hl.config({ cursor = { zoom_factor = 1 } })
end, "Reset zoom")
bind.exec("SUPER + CTRL + Delete", "Lock system", "loginctl lock-session")
