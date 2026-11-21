local bind = require("lib.bind")

local osdclient = "swayosd-client"

bind.locked_exec("XF86AudioRaiseVolume", "Volume up", osdclient .. " --output-volume raise", true)
bind.locked_exec("XF86AudioLowerVolume", "Volume down", osdclient .. " --output-volume lower", true)
bind.locked_exec("XF86AudioMute", "Mute", osdclient .. " --output-volume mute-toggle", true)
bind.locked_exec("XF86AudioMicMute", "Mute microphone", osdclient .. " --input-volume mute-toggle", true)
bind.locked_exec("XF86MonBrightnessUp", "Brightness up", osdclient .. " --brightness raise", true)
bind.locked_exec("XF86MonBrightnessDown", "Brightness down", osdclient .. " --brightness lower", true)

bind.locked_exec("ALT + XF86AudioRaiseVolume", "Volume up precise", osdclient .. " --output-volume +1", true)
bind.locked_exec("ALT + XF86AudioLowerVolume", "Volume down precise", osdclient .. " --output-volume -1", true)
bind.locked_exec("ALT + XF86MonBrightnessUp", "Brightness up precise", "brightnessctl set +1%", true)
bind.locked_exec("ALT + XF86MonBrightnessDown", "Brightness down precise", "brightnessctl set 1%-", true)

bind.locked_exec("XF86AudioNext", "Next track", osdclient .. " --playerctl next", false)
bind.locked_exec("XF86AudioPause", "Pause", osdclient .. " --playerctl play-pause", false)
bind.locked_exec("XF86AudioPlay", "Play", osdclient .. " --playerctl play-pause", false)
bind.locked_exec("XF86AudioPrev", "Previous track", osdclient .. " --playerctl previous", false)
bind.locked_exec("SUPER + XF86AudioMute", "Switch audio output", "lixx-menu audio-next", false)
