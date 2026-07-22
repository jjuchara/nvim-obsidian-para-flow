vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/.deps/mini.nvim")
vim.opt.swapfile = false

require("mini.test").setup({
  collect = {
    find_files = function()
      local files = vim.fn.globpath("tests", "*_spec.lua", false, true)
      return vim.tbl_filter(function(path)
        return not path:match("integration_spec%.lua$")
      end, files)
    end,
  },
})
