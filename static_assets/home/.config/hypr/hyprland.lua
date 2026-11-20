local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local hypr_home = config_home .. "/hypr"

package.path = table.concat({
    hypr_home .. "/hyprland/?.lua",
    package.path,
}, ";")

require("config.system")
require("config.appearance")
require("layouts.layout_ctrl")
require("layouts.dwindle")
require("layouts.master")
require("config.monitors")
require("config.workspaces")
require("rules.windows")
require("rules.apps")
require("config.input")
require("config.battery_alerts")
require("binds.window")
require("binds.system")
require("binds.clipboard")
require("binds.media")
require("binds.apps")
require("autostart")
require("config.spf_workspace")
require("config.hyprstudy")

-- Monique and personal integrations can install their own machine-local overrides.
for _, name in ipairs({ "monitors.lua", "local.lua" }) do
    local path = hypr_home .. "/" .. name
    local file = io.open(path, "r")
    if file then
        file:close()
        dofile(path)
    end
end
