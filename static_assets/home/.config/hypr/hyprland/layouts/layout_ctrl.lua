local bind = require("lib.bind")

local function set_active_workspace_layout(layout)
    return function()
        local workspace = hl.get_active_special_workspace() or hl.get_active_workspace()
        if not workspace then
            return
        end

        local workspace_name = workspace.special and tostring(workspace.name) or tostring(workspace.id)
        hl.workspace_rule({ workspace = workspace_name, layout = layout })
    end
end

local workspace_layouts = {
    { keycode = 10, layout = "dwindle" },
    { keycode = 11, layout = "master" },
    { keycode = 12, layout = "scrolling" },
    { keycode = 13, layout = "monocle" },
}

for _, workspace_layout in ipairs(workspace_layouts) do
    bind.bind(
        "SUPER + CTRL + code:" .. workspace_layout.keycode,
        set_active_workspace_layout(workspace_layout.layout),
        "Set workspace layout to " .. workspace_layout.layout
    )
end
