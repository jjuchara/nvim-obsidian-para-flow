local helpers = require("tests.helpers.config")
local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local trash = require("obsidian-para-flow.trash")
local ui = require("obsidian-para-flow.ui")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      cli._reset()
      config._reset()
      ui._reset()
    end,
    post_case = function()
      cli._reset()
      ui._reset()
    end,
  },
})

T["moves a confirmed relative Markdown note to Obsidian trash"] = function()
  local cfg = config.setup(helpers.valid())
  local argv
  cli._set_executor(function(value, _, callback)
    argv = value
    callback({ code = 0, stdout = "", stderr = "" })
  end)
  ui._set_select(function(items, options, callback)
    MiniTest.expect.equality(items, { "Cancel", "Move to trash" })
    MiniTest.expect.equality(options.prompt:find("1. Projects/Note.md", 1, true) ~= nil, true)
    callback("Move to trash")
  end)

  local result
  trash.confirm(cfg, "1. Projects/Note.md", function(value)
    result = value
  end)

  MiniTest.expect.equality(result.status, "deleted")
  MiniTest.expect.equality(argv, {
    "obsidian",
    "delete",
    "path=1. Projects/Note.md",
    "vault=Test Vault",
  })
end

T["cancels without mutation and rejects paths outside the vault"] = function()
  local cfg = config.setup(helpers.valid())
  local calls = 0
  cli._set_executor(function(_, _, callback)
    calls = calls + 1
    callback({ code = 0, stdout = "", stderr = "" })
  end)
  ui._set_select(function(_, _, callback)
    callback("Cancel")
  end)

  local canceled
  trash.confirm(cfg, "3. Resources/Note.md", function(value)
    canceled = value
  end)
  local invalid
  trash.confirm(cfg, "../Outside.md", function(value)
    invalid = value
  end)

  MiniTest.expect.equality(canceled.status, "canceled")
  MiniTest.expect.equality(invalid.status, "error")
  MiniTest.expect.equality(calls, 0)
end

return T
