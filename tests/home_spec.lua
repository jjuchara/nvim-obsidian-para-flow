local helpers = require("tests.helpers.config")
local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local home = require("obsidian-para-flow.home")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      home._reset()
      cli._reset()
      config._reset()
      config.setup(helpers.valid())
    end,
    post_case = function()
      home._reset()
      cli._reset()
    end,
  },
})

local function empty_executor(argv, _, callback)
  if argv[3] == "vault" then
    callback({ code = 0, stdout = "/tmp/test-vault", stderr = "" })
  elseif argv[3] == "files" then
    callback({ code = 0, stdout = "", stderr = "" })
  end
end

T["opens Home once with keyboard-complete mappings and closes cleanly"] = function()
  cli._set_executor(empty_executor)
  local tabs = #vim.api.nvim_list_tabpages()
  home.start()
  local active = home._current()
  MiniTest.expect.no_equality(active, nil)
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
  for _, key in ipairs({ "j", "k", "<Tab>", "p", "a", "r", "x", "n", "i", "f", "g", "R", "q" }) do
    MiniTest.expect.no_equality(vim.fn.maparg(key, "n", false, true).buffer, 0)
  end

  home.start()
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
  home._reset()
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs)
end

T["ignores stale section responses after reset"] = function()
  local pending = {}
  cli._set_executor(function(argv, _, callback)
    if argv[3] == "vault" then
      callback({ code = 0, stdout = "/tmp/test-vault", stderr = "" })
    elseif argv[3] == "files" then
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

local function press(key)
  vim.fn.maparg(key, "n", false, true).callback()
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

return T
