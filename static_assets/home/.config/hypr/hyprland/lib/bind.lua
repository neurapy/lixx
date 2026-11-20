local M = {}
local programs = {}

-- These are literal command names from the config. Resolve optional integrations
-- once per reload, so a fresh installation only advertises usable shortcuts.
function M.available(name)
    if programs[name] == nil then
        assert(name:match("^[%w._-]+$"))
        programs[name] = os.execute("command -v " .. name .. " >/dev/null") == true
    end
    return programs[name]
end

function M.optional_exec(keys, desc, cmd, opts)
    if M.available(cmd:match("^%S+")) then
        return M.exec(keys, desc, cmd, opts)
    end
end

local function with_desc(opts, desc)
    opts = opts or {}
    if desc and desc ~= "" then
        opts.description = desc
    end
    return opts
end

function M.bind(keys, dispatcher, desc, opts)
    return hl.bind(keys, dispatcher, with_desc(opts, desc))
end

function M.exec(keys, desc, cmd, opts)
    return M.bind(keys, hl.dsp.exec_cmd(cmd), desc, opts)
end

function M.locked_exec(keys, desc, cmd, repeating)
    return M.exec(keys, desc, cmd, { locked = true, repeating = repeating == true })
end

function M.resize_active_by_monitor_ratio(x_ratio, y_ratio)
    return function()
        local monitor = hl.get_active_monitor()
        local width = monitor and monitor.width or 1920
        local height = monitor and monitor.height or 1080
        local x = math.floor(width * x_ratio)
        local y = math.floor(height * y_ratio)

        hl.dispatch(hl.dsp.window.resize({ x = x, y = y, relative = true }))
    end
end

return M
