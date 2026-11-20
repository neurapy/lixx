local rule = require("lib.rule")

rule.window({
    {
        name = "terminal-tag",
        match = { class = "(Alacritty|kitty|com.mitchellh.ghostty)" },
        tag = "+terminal",
    },
    { name = "terminal-opacity-tag", match = { tag = "terminal" }, tag = "-default-opacity" },
    { name = "terminal-opacity", match = { tag = "terminal" }, opacity = "0.97 0.9" },
    { name = "terminal-touchpad-scroll", match = { class = "(Alacritty|kitty)" }, scroll_touchpad = 1.5 },
    { name = "ghostty-touchpad-scroll", match = { class = "com.mitchellh.ghostty" }, scroll_touchpad = 0.2 },

    {
        name = "browser-chromium-tag",
        match = { class = "((google-)?[cC]hrom(e|ium)|[bB]rave-browser|[mM]icrosoft-edge|Vivaldi-stable|helium)" },
        tag = "+chromium-based-browser",
    },
    {
        name = "browser-firefox-tag",
        match = { class = "([fF]irefox|zen|librewolf)" },
        tag = "+firefox-based-browser",
    },
    {
        name = "browser-video-remove-chromium-tag",
        match = { class = "(chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)" },
        tag = "-chromium-based-browser",
    },
    {
        name = "browser-video-remove-opacity-tag",
        match = { class = "(chrome-youtube.com__-Default|chrome-app.zoom.us__wc_home-Default)" },
        tag = "-default-opacity",
    },
    { name = "browser-chromium-tile", match = { tag = "chromium-based-browser" }, tile = true },
    { name = "browser-chromium-opaque", match = { tag = "chromium-based-browser" }, opacity = "1 1" },
    { name = "browser-firefox-opaque", match = { tag = "firefox-based-browser" }, opacity = "1 1" },
    { name = "chromium-touchpad-scroll", match = { class = "(chromium)" }, scroll_touchpad = 1.0 },

    { name = "floating-window-float", match = { tag = "floating-window" }, float = true },
    { name = "floating-window-center", match = { tag = "floating-window" }, center = true },
    { name = "floating-window-size", match = { tag = "floating-window" }, size = "875 600" },
    {
        name = "floating-app-tags",
        match = {
            class = "(org.omarchy.bluetui|org.omarchy.impala|org.omarchy.wiremix|org.omarchy.btop|org.omarchy.terminal|org.omarchy.bash|org.gnome.NautilusPreviewer|org.gnome.Evince|com.gabm.satty|Omarchy|About|TUI.float|imv|mpv)",
        },
        tag = "+floating-window",
    },
    {
        name = "floating-dialog-tags",
        match = {
            class = "(xdg-desktop-portal-gtk|sublime_text|DesktopEditors|org.gnome.Nautilus)",
            title = "^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to [open|save].*|[C|c]hoose.*)",
        },
        tag = "+floating-window",
    },
    { name = "calculator-float", match = { class = "org.gnome.Calculator" }, float = true },

    { name = "screensaver-fullscreen", match = { class = "org.omarchy.screensaver" }, fullscreen = true },
    { name = "screensaver-float", match = { class = "org.omarchy.screensaver" }, float = true },
    { name = "screensaver-animation", match = { class = "org.omarchy.screensaver" }, animation = "slide" },
    {
        name = "media-no-opacity-tag",
        match = { class = "^(zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$" },
        tag = "-default-opacity",
    },
    {
        name = "media-opaque",
        match = { class = "^(zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$" },
        opacity = "1 1",
    },
    { name = "pop-rounding", match = { tag = "pop" }, rounding = 8 },
    { name = "noidle", match = { tag = "noidle" }, idle_inhibit = "always" },

    { name = "pip-tag", match = { title = "(Picture.?in.?[Pp]icture)" }, tag = "+pip" },
    { name = "pip-opacity-tag", match = { tag = "pip" }, tag = "-default-opacity" },
    { name = "pip-float", match = { tag = "pip" }, float = true },
    { name = "pip-pin", match = { tag = "pip" }, pin = true },
    { name = "pip-size", match = { tag = "pip" }, size = "600 338" },
    { name = "pip-aspect", match = { tag = "pip" }, keep_aspect_ratio = true },
    { name = "pip-border", match = { tag = "pip" }, border_size = 0 },
    { name = "pip-opacity", match = { tag = "pip" }, opacity = "1 1" },
    { name = "pip-position", match = { tag = "pip" }, move = "(monitor_w-window_w-40) (monitor_h*0.04)" },

    { name = "webcam-float", match = { title = "WebcamOverlay" }, float = true },
    { name = "webcam-pin", match = { title = "WebcamOverlay" }, pin = true },
    { name = "webcam-no-initial-focus", match = { title = "WebcamOverlay" }, no_initial_focus = true },
    { name = "webcam-no-dim", match = { title = "WebcamOverlay" }, no_dim = true },
    { name = "webcam-position", match = { title = "WebcamOverlay" }, move = "(monitor_w-window_w-40) (monitor_h-window_h-40)" },

    {
        name = "jetbrains-splash",
        match = { class = "^(jetbrains-.*)$", title = "^(splash)$", float = true },
        tag = "+jetbrains-splash",
        center = true,
        no_focus = true,
        border_size = 0,
    },
    {
        name = "jetbrains-popup",
        match = { class = "^(jetbrains-.*)", title = "^(| )$", float = true },
        tag = "+jetbrains",
        center = true,
        stay_focused = true,
        border_size = 0,
        min_size = "(monitor_w*0.5) (monitor_h*0.5)",
    },
    {
        name = "jetbrains-tooltip",
        match = { class = "^(jetbrains-.*)$", title = "^(win.*)$", float = true },
        no_initial_focus = true,
    },
    {
        name = "jetbrains-focus",
        match = { class = "^(jetbrains-.*)$" },
        no_follow_mouse = true,
    },

    { name = "localsend-float", match = { class = "(Share|localsend)" }, float = true },
    { name = "localsend-center", match = { class = "(Share|localsend)" }, center = true },
    { name = "localsend-size", match = { class = "localsend" }, size = "1100 700" },

    { name = "steam-float", match = { class = "steam" }, float = true },
    { name = "steam-center-main", match = { class = "steam", title = "Steam" }, center = true },
    { name = "steam-opacity-tag", match = { class = "steam.*" }, tag = "-default-opacity" },
    { name = "steam-opaque", match = { class = "steam.*" }, opacity = "1 1" },
    { name = "steam-main-size", match = { class = "steam", title = "Steam" }, size = "1100 700" },
    { name = "steam-friends-size", match = { class = "steam", title = "Friends List" }, size = "460 800" },
    { name = "steam-idle-inhibit", match = { class = "steam" }, idle_inhibit = "fullscreen" },

    { name = "1password-private", match = { class = "^(1[p|P]assword)$" }, no_screen_share = true },
    { name = "1password-float-tag", match = { class = "^(1[p|P]assword)$" }, tag = "+floating-window" },
    { name = "bitwarden-private", match = { class = "^(Bitwarden)$" }, no_screen_share = true },
    { name = "bitwarden-float-tag", match = { class = "^(Bitwarden)$" }, tag = "+floating-window" },
    {
        name = "bitwarden-extension-private",
        match = { class = "chrome-nngceckbapebfimnlniiiahkandclblb-Default" },
        no_screen_share = true,
    },
    {
        name = "bitwarden-extension-float-tag",
        match = { class = "chrome-nngceckbapebfimnlniiiahkandclblb-Default" },
        tag = "+floating-window",
    },

    { name = "geforce-idle-inhibit", match = { class = "GeForceNOW" }, idle_inhibit = "fullscreen" },
    { name = "telegram-focus", match = { class = "org.telegram.desktop" }, focus_on_activate = false },
    { name = "davinci-floating-dialog-focus", match = { class = ".*[Rr]esolve.*", float = true }, stay_focused = true },
    { name = "gimp-opaque", match = { class = "(gimp)" }, opacity = "1.0 override 1.0 override" },
    { name = "qemu-opacity-tag", match = { class = "qemu" }, tag = "-default-opacity" },
    { name = "qemu-opaque", match = { class = "qemu" }, opacity = "1 1" },
    { name = "retroarch-fullscreen", match = { class = "com.libretro.RetroArch" }, fullscreen = true },
    { name = "retroarch-opacity-tag", match = { class = "com.libretro.RetroArch" }, tag = "-default-opacity" },
    { name = "retroarch-opaque", match = { class = "com.libretro.RetroArch" }, opacity = "1 1" },
    { name = "retroarch-idle-inhibit", match = { class = "com.libretro.RetroArch" }, idle_inhibit = "fullscreen" },
})

rule.layer({
    { name = "hyprshot-selection-no-anim", match = { namespace = "selection" }, no_anim = true },
    { name = "walker-no-anim", match = { namespace = "walker" }, no_anim = true },
})
