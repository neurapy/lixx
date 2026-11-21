return {
    "benlubas/molten-nvim",
    lazy = false,
    version = false,
    build = ":UpdateRemotePlugins",

    init = function()
        vim.g.molten_image_provider = "none"
        vim.g.molten_virt_text_output = true
        vim.g.molten_output_win_max_height = 20
    end,

    config = function()
        local function run_percent_cell()
            local current_line = vim.api.nvim_win_get_cursor(0)[1]
            local total_lines = vim.api.nvim_buf_line_count(0)

            local start_line = 1
            local end_line = total_lines

            -- Find the nearest "# %%" marker above the cursor.
            for line = current_line, 1, -1 do
                local text = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]

                if text and text:match("^%s*#%s*%%%%") then
                    start_line = line + 1
                    break
                end
            end

            -- Find the next "# %%" marker below the cursor.
            for line = current_line + 1, total_lines do
                local text = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]

                if text and text:match("^%s*#%s*%%%%") then
                    end_line = line - 1
                    break
                end
            end

            -- Ignore trailing empty lines before the next marker.
            while end_line >= start_line do
                local text = vim.api.nvim_buf_get_lines(0, end_line - 1, end_line, false)[1]

                if text and text:match("^%s*$") then
                    end_line = end_line - 1
                else
                    break
                end
            end

            if start_line > end_line then
                vim.notify("Current # %% cell is empty", vim.log.levels.WARN)
                return
            end

            -- Save the cursor position.
            local original_cursor = vim.api.nvim_win_get_cursor(0)

            -- Select the cell contents linewise.
            vim.api.nvim_win_set_cursor(0, { start_line, 0 })
            vim.cmd("normal! V")
            vim.api.nvim_win_set_cursor(0, { end_line, 0 })

            -- Evaluate the selected region.
            vim.cmd("MoltenEvaluateVisual")

            -- Return the cursor to its original position.
            vim.api.nvim_win_set_cursor(0, original_cursor)
        end

        vim.keymap.set("n", "<leader>mc", run_percent_cell, {
            desc = "Run current # %% cell",
            silent = true,
        })
    end,

    keys = {
        {
            "<leader>mi",
            "<cmd>MoltenInit<CR>",
            desc = "Select Jupyter kernel",
        },
        {
            "<leader>mr",
            ":<C-u>MoltenEvaluateVisual<CR>gv",
            mode = "v",
            desc = "Run selection",
        },
        {
            "<leader>ml",
            "<cmd>MoltenEvaluateLine<CR>",
            desc = "Run line",
        },
        {
            "<leader>mo",
            "<cmd>MoltenShowOutput<CR>",
            desc = "Show output",
        },
        {
            "<leader>mh",
            "<cmd>MoltenHideOutput<CR>",
            desc = "Hide output",
        },
        {
            "<leader>md",
            "<cmd>MoltenDelete<CR>",
            desc = "Delete cell output",
        },
        {
            "<leader>mR",
            "<cmd>MoltenReevaluateCell<CR>",
            desc = "Rerun existing Molten cell",
        },
    },
}
