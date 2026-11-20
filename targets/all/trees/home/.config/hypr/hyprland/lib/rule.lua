local M = {}

function M.window(specs)
    for _, spec in ipairs(specs) do
        hl.window_rule(spec)
    end
end

function M.layer(specs)
    for _, spec in ipairs(specs) do
        hl.layer_rule(spec)
    end
end

return M
