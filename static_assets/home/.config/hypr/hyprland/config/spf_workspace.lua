local bind = require("lib.bind")

if not bind.available("spf") then
    return
end

local WORKSPACE = "name:spf"
local WORKSPACE_NAME = "spf"
local ANCHOR_CLASS = "com.mitchellh.ghostty.spf"
local ANCHOR_CLASS_REGEX = "^com[.]mitchellh[.]ghostty[.]spf$"
local ANCHOR_COMMAND = table.concat({
    "uwsm app --",
    "env -u GTK_IM_MODULE -u QT_IM_MODULE -u XMODIFIERS",
    "ghostty",
    "--class=" .. ANCHOR_CLASS,
    "--title=SPF",
    "--working-directory=home",
    "-e spf",
}, " ")

local function has_process_argument(expected)
    local command_line = io.open("/proc/self/cmdline", "rb")
    if command_line == nil then
        return false
    end

    local contents = command_line:read("*a") or ""
    command_line:close()

    for argument in contents:gmatch("[^%z]+") do
        if argument == expected then
            return true
        end
    end

    return false
end

local VERIFYING_CONFIG = has_process_argument("--verify-config")

local anchor_starting = false
local focus_anchor_when_open = false
local shutting_down = false

local function is_spf_workspace(workspace)
    return workspace ~= nil and workspace.name == WORKSPACE_NAME
end

local function is_anchor(window)
    return window ~= nil and window.initial_class == ANCHOR_CLASS
end

local function is_viewer(window)
    return window ~= nil
        and window.mapped
        and not window.floating
        and not is_anchor(window)
        and is_spf_workspace(window.workspace)
end

local function defer(timeout, callback)
    hl.timer(callback, { timeout = timeout, type = "oneshot" })
end

hl.layout.register("spf-preview", {
    recalculate = function(ctx)
        local left = ctx:split(ctx.area, "left", 0.40)
        local right = ctx:split(ctx.area, "right", 0.60)

        for _, target in ipairs(ctx.targets) do
            target:place(is_anchor(target.window) and left or right)
        end
    end,
})

hl.workspace_rule({
    workspace = WORKSPACE,
    persistent = true,
    layout = "lua:spf-preview",
})

hl.window_rule({
    name = "spf-workspace-anchor",
    match = { initial_class = ANCHOR_CLASS_REGEX },
    workspace = WORKSPACE .. " silent",
    tile = true,
    group = "override deny",
    tag = "+terminal",
    opacity = "0.97 0.9",
    scroll_touchpad = 0.2,
})

hl.window_rule({
    name = "spf-workspace-tiled-viewers",
    match = {
        workspace = WORKSPACE,
        initial_class = "^(imv|mpv|org[.]gnome[.](Evince|Loupe|NautilusPreviewer))$",
        modal = false,
    },
    tile = true,
})

local function find_anchor()
    for _, window in ipairs(hl.get_windows()) do
        if window.mapped and is_anchor(window) then
            return window
        end
    end
end

local function focus_anchor(window)
    if window ~= nil and is_spf_workspace(window.workspace) and window.workspace.active then
        hl.dispatch(hl.dsp.focus({ window = window }))
    end
end

local function ensure_anchor(should_focus)
    if VERIFYING_CONFIG then
        return
    end

    local anchor = find_anchor()
    if anchor ~= nil then
        anchor_starting = false
        if should_focus then
            focus_anchor(anchor)
        end
        return
    end

    focus_anchor_when_open = focus_anchor_when_open or should_focus
    if anchor_starting or shutting_down then
        return
    end

    anchor_starting = true
    hl.exec_cmd(ANCHOR_COMMAND)

    defer(3000, function()
        anchor_starting = false
    end)
end

local function select_group_member(window)
    local group = window and window.group
    if group == nil or group.size < 2 then
        return
    end

    for index, member in ipairs(group.members) do
        if member == window then
            hl.dispatch(hl.dsp.group.active({
                index = index,
                window = window,
            }))
            return
        end
    end
end

local function reconcile_viewers(workspace, preferred)
    if not is_spf_workspace(workspace) then
        return
    end

    local canonical_group

    for _, window in ipairs(workspace:get_windows()) do
        if is_viewer(window) then
            if canonical_group == nil then
                if window.group == nil then
                    hl.dispatch(hl.dsp.group.toggle({
                        window = window,
                    }))
                end
                canonical_group = window.group
            elseif window.group ~= canonical_group then
                canonical_group:add(window)
            end
        end
    end

    if preferred ~= nil and is_viewer(preferred) then
        select_group_member(preferred)
    end
end

bind.bind("SUPER + R", function()
    hl.dispatch(hl.dsp.focus({
        workspace = WORKSPACE,
    }))
    ensure_anchor(true)
end, "Open SPF workspace")

hl.on("window.open", function(window)
    if is_anchor(window) then
        anchor_starting = false

        local should_focus = focus_anchor_when_open
        focus_anchor_when_open = false

        if should_focus then
            focus_anchor(window)
        end
        return
    end

    if is_viewer(window) then
        reconcile_viewers(window.workspace, window)
    end
end)

hl.on("window.move_to_workspace", function(window, workspace)
    if is_anchor(window) then
        if not is_spf_workspace(workspace) then
            defer(1, function()
                if window.mapped then
                    hl.dispatch(hl.dsp.window.move({
                        window = window,
                        workspace = WORKSPACE,
                        follow = false,
                    }))
                end
            end)
        end
        return
    end

    if is_spf_workspace(workspace) then
        defer(1, function()
            if is_viewer(window) then
                reconcile_viewers(window.workspace, window)
            end
        end)
    end
end)

hl.on("window.close", function(window)
    if not is_anchor(window) then
        return
    end

    local should_focus =
        is_spf_workspace(window.workspace)
        and window.workspace.active

    anchor_starting = false

    defer(100, function()
        ensure_anchor(should_focus)
    end)
end)

hl.on("workspace.active", function(workspace)
    if is_spf_workspace(workspace) then
        ensure_anchor(true)
    end
end)

hl.on("config.reloaded", function()
    ensure_anchor(false)

    local workspace = hl.get_workspace(WORKSPACE)
    if workspace ~= nil then
        reconcile_viewers(workspace)
    end
end)

hl.on("hyprland.start", function()
    ensure_anchor(false)
end)

hl.on("hyprland.shutdown", function()
    shutting_down = true
end)
