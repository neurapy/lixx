return {
        {
                "stevearc/conform.nvim",
                opts = function(_, opts)
                        opts.formatters_by_ft = opts.formatters_by_ft or {}
                        opts.formatters_by_ft.yaml = { "yamlfmt" }
                        opts.formatters_by_ft["yaml.docker-compose"] = { "yamlfmt" }
                        opts.formatters_by_ft["yaml.gitlab"] = { "yamlfmt" }
                        opts.formatters_by_ft["yaml.helm-values"] = { "yamlfmt" }

                        return opts
                end,
        },
}
