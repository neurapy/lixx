local bind = require("lib.bind")
local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local settings = config_home .. "/hyprstudy/settings.toml"
if not bind.available("hyprstudy") then
    return
end
local file = io.open(settings, "r")
if not file then
    return
end
file:close()

local function quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local launch = 'uwsm-app -- flock --nonblock --no-fork "$XDG_RUNTIME_DIR/hyprstudy.lock" hyprstudy ' .. quote(settings)

hl.workspace_rule({
    workspace = "special:hyprstudy",
    no_border = true,
    no_shadow = true,
    no_rounding = true,
    decorate = false,
    gaps_in = 0,
    gaps_out = 0,
})

hl.on("workspace.created", function(workspace)
    if workspace.is_empty and workspace.addressable_name == "special:hyprstudy" then
        hl.exec_cmd(launch, { workspace = workspace.addressable_name .. " silent" })
    end
end)

hl.window_rule({
    name = "hyprstudy-workspace",
    match = { class = "^(hyprstudy)$" },
    workspace = "special:hyprstudy silent",
    fullscreen = true,
    no_blur = true,
})

hl.bind("SUPER + Q", hl.dsp.workspace.toggle_special("hyprstudy"), {
    description = "hyprstudy ein-/ausblenden",
})
