return {
    {
        "mason-org/mason.nvim",
        opts = function(_, opts)
            -- The Rust and Clang extras both request the same debugger.
            opts.ensure_installed = vim.list.unique(opts.ensure_installed)
        end,
    },
    {
        "neovim/nvim-lspconfig",
        lazy = false,
        opts = {
            servers = {
                clangd = {
                    cmd = {
                        "clangd",
                        "--background-index",
                        "--query-driver=/usr/bin/arm-none-eabi-gcc",
                        "--log=error",
                    },
                },

                lua_ls = {
                    settings = {
                        Lua = {
                            runtime = {
                                version = "LuaJIT",
                            },
                            diagnostics = {
                                globals = { "vim" },
                            },
                            workspace = {
                                library = vim.api.nvim_get_runtime_file("", true),
                                checkThirdParty = false,
                            },
                            telemetry = {
                                enable = false,
                            },
                        },
                    },
                },

                yamlls = {
                    before_init = function(_, new_config)
                        new_config.settings.yaml.schemas = vim.tbl_deep_extend(
                            "force",
                            new_config.settings.yaml.schemas or {},
                            require("schemastore").yaml.schemas({
                                ignore = { "Problem package format" },
                            })
                        )
                    end,

                    settings = {
                        yaml = {
                            yamlVersion = "1.1",
                            -- Keep formatting in Conform/yamlfmt.
                            format = {
                                enable = false,
                            },

                            validate = true,
                            completion = true,
                            hover = true,

                            schemas = {
                                ["schema/yappl_schema.json"] = {
                                    "examples/*.yaml",
                                },
                            },
                        },
                    },
                },
            },
        },
    },
}
