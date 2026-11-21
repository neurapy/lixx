local function update_parsers()
        return require("nvim-treesitter").update(nil, { summary = true, max_jobs = 1 })
end

return {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        version = false, -- last release is way too old and doesn't work on Windows
        build = function()
                -- The config below handles first setup once Mason has installed the CLI.
                if vim.fn.executable("tree-sitter") == 1 then
                        update_parsers()
                end
        end,
        event = { "LazyFile", "VeryLazy" },
        cmd = { "TSUpdate", "TSInstall", "TSLog", "TSUninstall" },
        opts_extend = { "ensure_installed" },
        ---@alias lazyvim.TSFeat { enable?: boolean, disable?: string[] }
        ---@class lazyvim.TSConfig: TSConfig
        opts = {
                -- LazyVim config for treesitter
                indent = { enable = true }, ---@type lazyvim.TSFeat
                highlight = { enable = true }, ---@type lazyvim.TSFeat
                folds = { enable = true }, ---@type lazyvim.TSFeat
                ensure_installed = {
                        "bash",
                        "c",
                        "diff",
                        "html",
                        "javascript",
                        "jsdoc",
                        "json",
                        "lua",
                        "luadoc",
                        "luap",
                        "markdown",
                        "markdown_inline",
                        "printf",
                        "python",
                        "query",
                        "regex",
                        "toml",
                        "tsx",
                        "typescript",
                        "vim",
                        "vimdoc",
                        "xml",
                        "yaml",
                },
        },
        ---@param opts lazyvim.TSConfig
        config = function(_, opts)
                local TS = require("nvim-treesitter")

                setmetatable(require("nvim-treesitter.install"), {
                        __newindex = function(_, k)
                                if k == "compilers" then
                                        vim.schedule(function()
                                                LazyVim.error({
                                                        "Setting custom compilers for `nvim-treesitter` is no longer supported.",
                                                        "",
                                                        "For more info, see:",
                                                        "- [compilers](https://docs.rs/cc/latest/cc/#compile-time-requirements)",
                                                })
                                        end)
                                end
                        end,
                })

                -- some quick sanity checks
                if not TS.get_installed then
                        return LazyVim.error("Please use `:Lazy` and update `nvim-treesitter`")
                elseif type(opts.ensure_installed) ~= "table" then
                        return LazyVim.error("`nvim-treesitter` opts.ensure_installed must be a table")
                end

                -- setup treesitter
                TS.setup(opts)
                LazyVim.treesitter.get_installed(true) -- initialize the installed langs
                -- Neovim can cache the runtime path before this directory exists on first launch.
                vim.opt.runtimepath:prepend(opts.install_dir or vim.fn.stdpath("data") .. "/site")

                -- install missing parsers
                local install = vim.tbl_filter(function(lang)
                        return not LazyVim.treesitter.have(lang)
                end, opts.ensure_installed or {})
                local missing_cli = vim.fn.executable("tree-sitter") == 0
                local function install_missing()
                        if #install > 0 then
                                TS.install(install, { summary = true, max_jobs = 1 }):await(function()
                                        LazyVim.treesitter.get_installed(true) -- refresh the installed langs
                                end)
                        end
                end
                if missing_cli or #install > 0 then
                        LazyVim.treesitter.build(function()
                                if missing_cli and #TS.get_installed("parsers") > 0 then
                                        update_parsers():await(install_missing)
                                else
                                        install_missing()
                                end
                        end)
                end

                vim.api.nvim_create_autocmd("FileType", {
                        group = vim.api.nvim_create_augroup("lazyvim_treesitter", { clear = true }),
                        callback = function(ev)
                                local ft, lang = ev.match, vim.treesitter.language.get_lang(ev.match)
                                if not LazyVim.treesitter.have(ft) then
                                        return
                                end

                                ---@param feat string
                                ---@param query string
                                local function enabled(feat, query)
                                        local f = opts[feat] or {} ---@type lazyvim.TSFeat
                                        return f.enable ~= false
                                                and not (type(f.disable) == "table" and vim.tbl_contains(
                                                        f.disable,
                                                        lang
                                                ))
                                                and LazyVim.treesitter.have(ft, query)
                                end

                                -- highlighting
                                if enabled("highlight", "highlights") then
                                        pcall(vim.treesitter.start, ev.buf)
                                end

                                -- indents
                                if enabled("indent", "indents") then
                                        LazyVim.set_default("indentexpr", "v:lua.LazyVim.treesitter.indentexpr()")
                                end

                                -- folds
                                if enabled("folds", "folds") then
                                        if LazyVim.set_default("foldmethod", "expr") then
                                                LazyVim.set_default("foldexpr", "v:lua.LazyVim.treesitter.foldexpr()")
                                        end
                                end
                        end,
                })
        end,
}
