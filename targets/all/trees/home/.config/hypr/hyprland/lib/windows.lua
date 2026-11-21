local M = {}

-- Keep the user's configured dimensions so toggling twice restores this layout.
local saved
function M.gaps()
    if saved then
        hl.config(saved)
        saved = nil
    else
        saved = { general = {
            gaps_in = hl.get_config("general.gaps_in"), gaps_out = hl.get_config("general.gaps_out"),
            border_size = hl.get_config("general.border_size"),
        }, decoration = { rounding = hl.get_config("decoration.rounding") } }
        hl.config({ general = { gaps_in = 0, gaps_out = 0, border_size = 0 }, decoration = { rounding = 0 } })
    end
end

function M.square()
    local ratio = hl.get_config("layout.single_window_aspect_ratio")
    hl.config({ layout = { single_window_aspect_ratio = ratio.x == 1 and "0 0" or "1 1" } })
end

function M.pop()
    local win = hl.get_active_window()
    if not win then return end
    if win.pinned then
        hl.dispatch(hl.dsp.window.pin())
        hl.dispatch(hl.dsp.window.float({ action = "unset" }))
    else
        hl.dispatch(hl.dsp.window.float({ action = "set" }))
        hl.dispatch(hl.dsp.window.resize({ x = 1300, y = 900 }))
        hl.dispatch(hl.dsp.window.center())
        hl.dispatch(hl.dsp.window.pin())
        hl.dispatch(hl.dsp.window.bring_to_top())
    end
end

function M.close_all()
    for _, win in ipairs(hl.get_windows()) do
        if win.mapped then hl.dispatch(hl.dsp.window.close({ window = win })) end
    end
    hl.dispatch(hl.dsp.focus({ workspace = 1 }))
end

function M.scale()
    local monitor = hl.get_active_monitor()
    if not monitor then return end
    local scales = { 1, 1.25, 1.6, 2, 3, 4 }
    local nearest = 1
    for i, scale in ipairs(scales) do
        if math.abs(scale - monitor.scale) < math.abs(scales[nearest] - monitor.scale) then nearest = i end
    end
    hl.monitor({ output = monitor.name, mode = string.format("%dx%d@%.3f", monitor.width, monitor.height, monitor.refresh_rate),
        position = monitor.x .. "x" .. monitor.y, transform = monitor.transform, scale = scales[nearest % #scales + 1] })
end

return M
