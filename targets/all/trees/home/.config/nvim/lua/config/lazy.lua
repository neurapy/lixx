local plugin_dir = vim.fn.stdpath("data") .. "/lazy"

-- Install the framework before lazy.nvim resolves imports. Otherwise its first
-- partial plugin list can overwrite pins for extras it hasn't discovered yet.
local function bootstrap(name, repo)
        local path = plugin_dir .. "/" .. name
        if vim.uv.fs_stat(path) then return end
        local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
        local revision = assert(lock[name] and lock[name].commit, "Missing plugin pin for " .. name)
        vim.fn.mkdir(plugin_dir, "p")
        local temporary = assert(vim.uv.fs_mkdtemp(plugin_dir .. "/.bootstrap-XXXXXX"))
        local function git(args)
                local result = vim.system(args, { text = true }):wait()
                if result.code ~= 0 then
                        vim.fn.delete(temporary, "rf")
                        error("Could not install " .. name .. ": " .. result.stderr)
                end
        end
        git({ "git", "clone", "--filter=blob:none", "--no-checkout", repo, temporary })
        git({ "git", "-C", temporary, "checkout", "--detach", revision })
        local installed, message = vim.uv.fs_rename(temporary, path)
        if not installed then
                vim.fn.delete(temporary, "rf")
                assert(vim.uv.fs_stat(path), message)
        end
end

bootstrap("lazy.nvim", "https://github.com/folke/lazy.nvim.git")
bootstrap("LazyVim", "https://github.com/LazyVim/LazyVim.git")
vim.opt.rtp:prepend(plugin_dir .. "/lazy.nvim")

require("lazy").setup({
        spec = {
                { "LazyVim/LazyVim", import = "lazyvim.plugins" },
                { import = "plugins" },
        },
        defaults = {
                -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
                -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
                lazy = false,
                -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
                -- have outdated releases, which may break your Neovim install.
                version = false, -- always use the latest git commit
                -- version = "*", -- try installing the latest stable version for plugins that support semver
        },
        install = { colorscheme = { "tokyonight", "habamax" } },
        checker = {
                enabled = true, -- check for plugin updates periodically
                notify = false, -- notify on update
        }, -- automatically check for plugin updates
        performance = {
                rtp = {
                        -- Keep the packaged core parsers on Neovim's runtime path.
                        reset = false,
                        -- disable some rtp plugins
                        disabled_plugins = {
                                "gzip",
                                -- "matchit",
                                -- "matchparen",
                                -- "netrwPlugin",
                                "tarPlugin",
                                "tohtml",
                                "tutor",
                                "zipPlugin",
                        },
                },
        },
})
