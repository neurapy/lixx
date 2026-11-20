-- UWSM publishes the compositor environment before starting desktop clients.
hl.on("hyprland.start", function()
    hl.exec_cmd([[
        uwsm finalize HYPRLAND_INSTANCE_SIGNATURE &&
        systemctl --user start --no-block hypridle.service hyprsunset.service swaync.service \
            hyprpolkitagent.service org.freedesktop.IBus.session.generic.service lixx-waybar.service
    ]])
end)
