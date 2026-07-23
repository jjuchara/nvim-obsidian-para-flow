local helpers = require("tests.helpers.config")
local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local home = require("obsidian-para-flow.home")
local ui = require("obsidian-para-flow.ui")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      home._reset()
      cli._reset()
      config._reset()
      ui._reset()
      config.setup(helpers.valid())
    end,
    post_case = function()
      home._reset()
      cli._reset()
      ui._reset()
    end,
  },
})

local function empty_executor(argv, _, callback)
  if argv[2] == "vault" then
    callback({ code = 0, stdout = "/tmp/test-vault", stderr = "" })
  elseif argv[2] == "files" then
    callback({ code = 0, stdout = "", stderr = "" })
  end
end

local function press(key)
  vim.fn.maparg(key, "n", false, true).callback()
end

T["opens Home once with keyboard-complete mappings and closes cleanly"] = function()
  cli._set_executor(empty_executor)
  local tabs = #vim.api.nvim_list_tabpages()
  home.start()
  local active = home._current()
  MiniTest.expect.no_equality(active, nil)
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
  for _, key in ipairs({ "j", "k", "<Tab>", "p", "a", "r", "x", "d", "n", "i", "f", "g", "R", "q" }) do
    MiniTest.expect.no_equality(vim.fn.maparg(key, "n", false, true).buffer, 0)
  end

  home.start()
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
  home._reset()
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs)
end

T["moves the selected note to trash from overview and removes it from Home"] = function()
  local deleted
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "vault" then
      callback({ code = 0, stdout = "/tmp/test-vault", stderr = "" })
    elseif argv[2] == "files" then
      callback({ code = 0, stdout = "", stderr = "" })
    elseif argv[2] == "delete" then
      deleted = argv[3]
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end)
  ui._set_select(function(_, _, callback)
    callback("Move to trash")
  end)
  home.start()
  local active = home._current()
  local item = {
    path = "1. Projects/Note.md",
    name = "Note",
    category = "projects",
    group = "No status",
    properties = { tags = { "projects" } },
    info = { created = 1, modified = 1 },
  }
  active.active_section = "projects"
  active.sections.projects = {
    status = "ready",
    data = {
      category = "projects",
      items = { item },
      groups = { { name = "No status", items = { item } } },
    },
  }

  press("d")

  MiniTest.expect.equality(deleted, "path=1. Projects/Note.md")
  MiniTest.expect.equality(#active.sections.projects.data.items, 0)
  MiniTest.expect.equality(active.pending_delete, nil)
end

T["ignores stale section responses after reset"] = function()
  local pending = {}
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "vault" then
      callback({ code = 0, stdout = "/tmp/test-vault", stderr = "" })
    elseif argv[2] == "files" then
      table.insert(pending, callback)
    end
  end)
  home.start()
  home._reset()
  for _, callback in ipairs(pending) do
    callback({ code = 0, stdout = "", stderr = "" })
  end
  MiniTest.expect.equality(home._current(), nil)
end

local function feed(keys)
  local index = 0
  home._set_getchar(function()
    index = index + 1
    return keys[index] or "\27"
  end)
end

T["narrows the filter while typing and restores it on cancel"] = function()
  cli._set_executor(empty_executor)
  home.start()
  press("r")

  feed({ "р", "е", "с", "\8", "\13" })
  press("/")
  local active = home._current()
  MiniTest.expect.equality(active.filter, "ре")
  MiniTest.expect.equality(active.filtering, false)

  feed({ "у", "р", "с", "\27" })
  press("/")
  MiniTest.expect.equality(active.filter, "ре")

  press("<Esc>")
  MiniTest.expect.equality(active.filter, "")
end

T["ignores the filter outside a full section"] = function()
  cli._set_executor(empty_executor)
  home.start()
  feed({ "р", "\13" })
  press("/")
  MiniTest.expect.equality(home._current().filter, "")
end

T["opens a selected Home note in a new tab without replacing the origin buffer"] = function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/1. Projects", "p")
  local note_path = root .. "/1. Projects/Note.md"
  vim.fn.writefile({ "# Note" }, note_path)
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "vault" then
      callback({ code = 0, stdout = root, stderr = "" })
    elseif argv[2] == "files" then
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end)

  local origin_buffer = vim.api.nvim_get_current_buf()
  local tabs = #vim.api.nvim_list_tabpages()
  home.start()
  local active = home._current()
  active.active_section = "projects"
  active.sections.projects = {
    status = "ready",
    data = { items = { { path = "1. Projects/Note.md", name = "Note" } } },
  }

  press("<CR>")

  MiniTest.expect.equality(home._current(), nil)
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(note_path))
  MiniTest.expect.equality(vim.api.nvim_buf_is_valid(origin_buffer), true)
  vim.cmd("tabclose")
  vim.fn.delete(root, "rf")
end

return T
