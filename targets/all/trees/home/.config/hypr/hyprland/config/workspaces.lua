local workspaces = {
    { workspace = "5", monitor = "", default = true },
    { workspace = "1", monitor = "eDP-1", default = true },
    { workspace = "2", monitor = "eDP-1" },
    { workspace = "3", monitor = "eDP-1" },
    { workspace = "4", monitor = "eDP-1" },
    {
        workspace = "special:termispace",
        no_border = true,
        no_shadow = true,
        no_rounding = true,
        decorate = false,
    },
    {
        workspace = "special:slackspace",
        no_border = true,
        no_shadow = true,
        no_rounding = true,
        decorate = false,
    },
    { workspace = "special:scratchpad" },
}

for _, workspace in ipairs(workspaces) do
    hl.workspace_rule(workspace)
end

local workspace_programs = {
    ["special:termispace"] = [[ghostty --background-opacity=0.0 --fullscreen=true --title="termispace-win" -e zsh]],
}

if require("lib.bind").available("slack") then
    workspace_programs["special:slackspace"] = "slack"
end

hl.on("workspace.created", function(workspace)
    local command = workspace_programs[workspace.addressable_name]
    if workspace.is_empty and command then
        hl.exec_cmd(command, { workspace = workspace.addressable_name .. " silent" })
    end
end)
