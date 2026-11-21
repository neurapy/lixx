-- Options are automatically loaded before lazy.nvim startup
-- Add any additional options here

-- vim.opt.shiftwidth = 4
-- vim.opt.tabstop = 4
vim.opt.softtabstop = -1 -- folgt shiftwidth
vim.opt.expandtab = true
vim.opt.autoindent = true

vim.opt.spelllang = { "en", "de" }

local molten_python = vim.fn.stdpath("data") .. "/molten-venv/bin/python"
vim.g.python3_host_prog = vim.fn.executable(molten_python) == 1 and molten_python or "/usr/bin/python3"
-- vim.opt.conceallevel = 0 -- Right now this has to be set for the notebook_seperators to work.
-- vim.opt.concealcursor = ""
