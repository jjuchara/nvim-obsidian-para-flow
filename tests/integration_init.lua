vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/.deps/mini.nvim")
vim.opt.swapfile = false

require("mini.test").setup()
