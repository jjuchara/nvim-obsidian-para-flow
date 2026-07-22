local source = debug.getinfo(1, "S").source
local init_path = source:sub(1, 1) == "@" and source:sub(2) or source
local tests_directory = vim.fn.fnamemodify(init_path, ":p:h")
local repository = vim.fn.fnamemodify(tests_directory, ":h")
vim.opt.runtimepath:prepend(repository)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local vault = assert(
  vim.env.OBSIDIAN_PARA_TEST_VAULT,
  "OBSIDIAN_PARA_TEST_VAULT is required for manual testing"
)

require("obsidian-para-flow").setup({
  vault = vault,
  inbox = {
    folder = "6. Inbox",
    quickadd_choice = "inbox",
  },
  para = {
    projects = { folder = "1. Projects", link = "[[My Projects]]" },
    areas = { folder = "2. Areas", link = "[[My Areas]]" },
    resources = { folder = "3. Resources" },
    archives = { folder = "4. Archives" },
  },
  review = {
    layout = vim.env.OBSIDIAN_PARA_TEST_LAYOUT or "float",
    width = 0.7,
    height = 0.7,
  },
})
