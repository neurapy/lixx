-- Laptop battery warnings, independent of SwayNC's Do Not Disturb setting.
-- Preview: hyprctl eval 'require("config.battery_alerts").preview()'
-- Power restored preview: hyprctl eval 'require("config.battery_alerts").power_restored()'
local M = {}
local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local FLASH_SHADER = config_home .. "/hypr/shaders/battery-warning.glsl"
local RESTORED_SHADER = config_home .. "/hypr/shaders/battery-restored.glsl"
local PULSE_MS = 400

local notice
local flash_generation = 0
local original_shader
local active_shader

local function current_shader()
    return hl.get_config("decoration.screen_shader") or ""
end

local function set_shader(path)
    hl.config({ decoration = { screen_shader = path } })
end

local function stop_flash()
    flash_generation = flash_generation + 1
    -- Restore only our own effect; preserve shader changes made by the user.
    if original_shader ~= nil and current_shader() == active_shader then
        set_shader(original_shader)
    end
    original_shader = nil
    active_shader = nil
end

local function flash_screen(shader, pulse_count)
    stop_flash()
    local saved = current_shader()
    original_shader = saved
    active_shader = shader
    local generation = flash_generation
    set_shader(shader)

    local final_phase = pulse_count * 2 - 1
    for phase = 1, final_phase do
        hl.timer(function()
            if generation ~= flash_generation then
                return
            end
            local expected = phase % 2 == 0 and saved or shader
            if current_shader() ~= expected then
                stop_flash()
                return
            end
            if phase == final_phase then
                stop_flash()
            else
                set_shader(phase % 2 == 0 and shader or saved)
            end
        end, { timeout = phase * PULSE_MS, type = "oneshot" })
    end
end

function M.clear()
    if notice and notice:is_alive() then
        notice:dismiss()
    end
    notice = nil
end

function M.warn(percent, flash)
    M.clear()
    local text = string.format("BATTERY %d%%", percent)
    local color = flash and "rgb(ff4d4d)" or "rgb(ffcc66)"
    notice = hl.notification.create({
        text = text,
        timeout = 6000,
        icon = "warning",
        color = color,
        font_size = 26,
    })
    if flash then
        flash_screen(FLASH_SHADER, 2)
    end
    return notice
end

function M.power_restored()
    M.clear()
    flash_screen(RESTORED_SHADER, 1)
end

function M.preview()
    return M.warn(10, true)
end

function M.stop()
    stop_flash()
    M.clear()
end

hl.on("hyprland.shutdown", M.stop)
hl.on("config.unload", M.stop)

return M
