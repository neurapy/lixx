local M = {}

local title = "Markdown Export"
local static_dir = vim.fn.stdpath("data") .. "/lazy/markdown-preview.nvim/app/_static"
local template_dir = vim.fn.stdpath("config") .. "/lua/config/templates"
local html_template = template_dir .. "/markdown-preview-dark.html"
local pdf_header = template_dir .. "/markdown-preview-dark.tex"

local function notify(message, level)
        vim.notify(message, level or vim.log.levels.INFO, { title = title })
end

local function pdf_theme()
        local theme = vim.g.markdown_export_pdf_theme

        if theme == nil then
                return "dark"
        end

        theme = tostring(theme):lower()
        if theme == "light" then
                return "light"
        end

        return "dark"
end

local function output_path(input, extension)
        return vim.fn.fnamemodify(input, ":r") .. "." .. extension
end

local function ensure_saved(buf)
        local path = vim.api.nvim_buf_get_name(buf)

        if path == "" then
                notify("Save the Markdown buffer before exporting.", vim.log.levels.ERROR)
                return nil
        end

        if vim.bo[buf].modified then
                local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
                        vim.cmd("silent write")
                end)

                if not ok then
                        notify("Could not save before exporting: " .. tostring(err), vim.log.levels.ERROR)
                        return nil
                end
        end

        return vim.fn.fnamemodify(path, ":p")
end

local function finish_export(result, output, opts)
        if result.code == 0 then
                notify("Exported " .. output)

                if opts.open ~= false then
                        pcall(vim.ui.open, output)
                end

                return true
        end

        local details = vim.trim((result.stderr or "") .. "\n" .. (result.stdout or ""))
        if details == "" then
                details = "pandoc exited with code " .. tostring(result.code)
        end

        notify(details, vim.log.levels.ERROR)
        return false
end

local function run_pandoc(format, extra_args, opts)
        opts = opts or {}

        if vim.fn.executable("pandoc") ~= 1 then
                notify("pandoc is not installed.", vim.log.levels.ERROR)
                return false
        end

        if format == "pdf" and vim.fn.executable("xelatex") ~= 1 then
                notify(
                        "xelatex is not installed. Install it with: sudo apt install texlive-xetex texlive-latex-extra texlive-fonts-recommended",
                        vim.log.levels.ERROR
                )
                return false
        end

        local buf = opts.buf or vim.api.nvim_get_current_buf()
        local input = ensure_saved(buf)
        if not input then
                return false
        end

        local output = output_path(input, format)
        local cwd = vim.fn.fnamemodify(input, ":h")
        local cmd = {
                "pandoc",
                input,
                "--from=markdown+tex_math_dollars+autolink_bare_uris+emoji",
                "-o",
                output,
        }

        vim.list_extend(cmd, extra_args)

        if opts.wait then
                return finish_export(vim.system(cmd, { cwd = cwd, text = true }):wait(), output, opts)
        end

        notify("Exporting " .. output .. "...")
        vim.system(cmd, { cwd = cwd, text = true }, function(result)
                vim.schedule(function()
                        finish_export(result, output, opts)
                end)
        end)

        return true
end

function M.export_html(opts)
        return run_pandoc("html", {
                "--to=html5",
                "--standalone",
                "--embed-resources",
                "--template=" .. html_template,
                "--css=" .. static_dir .. "/page.css",
                "--css=" .. static_dir .. "/markdown.css",
                "--css=" .. static_dir .. "/highlight.css",
                "--mathml",
        }, opts)
end

function M.export_pdf(opts)
        local args = {
                "--pdf-engine=xelatex",
                "-V",
                "geometry:margin=1in",
        }

        if pdf_theme() == "dark" then
                vim.list_extend(args, {
                        "--include-in-header=" .. pdf_header,
                        "-V",
                        "colorlinks=true",
                        "-V",
                        "linkcolor=MarkdownPreviewLink",
                        "-V",
                        "urlcolor=MarkdownPreviewLink",
                })
        end

        return run_pandoc("pdf", args, opts)
end

function M.set_pdf_theme(theme)
        theme = tostring(theme or ""):lower()

        if theme ~= "dark" and theme ~= "light" then
                notify("PDF export theme must be 'dark' or 'light'.", vim.log.levels.ERROR)
                return false
        end

        vim.g.markdown_export_pdf_theme = theme
        notify("PDF export theme: " .. theme)
        return true
end

function M.toggle_pdf_theme()
        local next_theme = pdf_theme() == "dark" and "light" or "dark"
        return M.set_pdf_theme(next_theme)
end

function M.setup()
        local group = vim.api.nvim_create_augroup("markdown_static_export", { clear = true })
        local function attach(buf)
                if vim.b[buf].markdown_static_export_setup then
                        return
                end

                vim.b[buf].markdown_static_export_setup = true

                vim.api.nvim_buf_create_user_command(buf, "MarkdownExportHtml", function()
                        M.export_html({ buf = buf })
                end, { desc = "Export Markdown to static HTML", force = true })

                vim.api.nvim_buf_create_user_command(buf, "MarkdownExportPdf", function()
                        M.export_pdf({ buf = buf })
                end, { desc = "Export Markdown to PDF", force = true })

                vim.api.nvim_buf_create_user_command(buf, "MarkdownExportPdfToggleTheme", function()
                        M.toggle_pdf_theme()
                end, { desc = "Toggle Markdown PDF export theme", force = true })

                vim.api.nvim_buf_create_user_command(buf, "MarkdownExportPdfDark", function()
                        M.set_pdf_theme("dark")
                end, { desc = "Use dark Markdown PDF export theme", force = true })

                vim.api.nvim_buf_create_user_command(buf, "MarkdownExportPdfLight", function()
                        M.set_pdf_theme("light")
                end, { desc = "Use light Markdown PDF export theme", force = true })

                vim.keymap.set("n", "<leader>ch", function()
                        M.export_html({ buf = buf })
                end, { buffer = buf, desc = "Markdown Export HTML" })

                vim.keymap.set("n", "<leader>cP", function()
                        M.export_pdf({ buf = buf })
                end, { buffer = buf, desc = "Markdown Export PDF" })

                vim.keymap.set("n", "<leader>cT", function()
                        M.toggle_pdf_theme()
                end, { buffer = buf, desc = "Markdown PDF Theme Toggle" })
        end

        vim.api.nvim_create_autocmd("FileType", {
                group = group,
                pattern = "markdown",
                callback = function(event)
                        attach(event.buf)
                end,
        })

        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "markdown" then
                        attach(buf)
                end
        end
end

return M
