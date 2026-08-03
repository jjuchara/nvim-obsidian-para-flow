local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local date_picker = require("obsidian-para-flow.date_picker")
local workflow = require("obsidian-para-flow.date_property")
local helpers = require("tests.helpers.config")
local ui = require("obsidian-para-flow.ui")
local vault = require("obsidian-para-flow.vault")

local original_pick = date_picker.pick

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      cli._reset()
      config._reset()
      ui._reset()
      vault._reset()
      config.setup(helpers.valid())
    end,
    post_case = function()
      date_picker.pick = original_pick
      cli._reset()
      ui._reset()
      vault._reset()
      pcall(vim.cmd, "bwipeout!")
    end,
  },
})

local function open_note()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/3. Resources", "p")
  local path = root .. "/3. Resources/Note.md"
  vim.fn.writefile({ "# Note" }, path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  return root, path
end

T["resolves only Markdown notes inside the vault"] = function()
  local root, path = open_note()
  MiniTest.expect.equality(workflow.relative_path(root, path), "3. Resources/Note.md")
  MiniTest.expect.equality(workflow.relative_path(root, root .. "/Outside.txt"), nil)
  MiniTest.expect.equality(workflow.relative_path(root, vim.fn.tempname() .. ".md"), nil)
end

T["selects a known property and writes the picked date through the typed CLI"] = function()
  local root = open_note()
  local calls = {}
  local properties_calls = 0
  ui._set_select(function(items, options, callback)
    MiniTest.expect.equality(items, { "expired_at", "deadline" })
    MiniTest.expect.equality(options.prompt, "Date property: ")
    callback("expired_at")
  end)
  date_picker.pick = function(options, callback)
    MiniTest.expect.equality(options.picker, "calendar")
    MiniTest.expect.equality(options.title, "Set expired_at")
    MiniTest.expect.equality(options.initial, "2026-08-01")
    callback({ action = "select", value = "2026-08-15" })
  end
  cli._set_executor(function(argv, _, callback)
    calls[#calls + 1] = argv
    if argv[2] == "vault" then
      callback({ code = 0, stdout = argv[3] == "info=name" and "Test Vault" or root, stderr = "" })
    elseif argv[2] == "properties" then
      properties_calls = properties_calls + 1
      callback({ code = 0, stdout = '{"expired_at":"2026-08-01"}', stderr = "" })
    elseif argv[2] == "property:set" then
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end)

  workflow.start()

  MiniTest.expect.equality(properties_calls, 2)
  MiniTest.expect.equality(calls[#calls], {
    "obsidian",
    "property:set",
    "path=3. Resources/Note.md",
    "name=expired_at",
    "value=2026-08-15",
    "type=date",
    "vault=Test Vault",
  })
end

T["cancels without mutation and refuses changed metadata"] = function()
  local root = open_note()
  local set_calls = 0
  local properties_calls = 0
  ui._set_select(function(_, _, callback)
    callback("deadline")
  end)
  date_picker.pick = function(_, callback)
    callback({ action = "cancel" })
  end
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "vault" then
      callback({ code = 0, stdout = argv[3] == "info=name" and "Test Vault" or root, stderr = "" })
    elseif argv[2] == "properties" then
      properties_calls = properties_calls + 1
      callback({ code = 0, stdout = "{}", stderr = "" })
    elseif argv[2] == "property:set" then
      set_calls = set_calls + 1
    end
  end)
  workflow.start()
  MiniTest.expect.equality(properties_calls, 1)
  MiniTest.expect.equality(set_calls, 0)

  date_picker.pick = function(_, callback)
    callback({ action = "select", value = "2026-08-20" })
  end
  properties_calls = 0
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "vault" then
      callback({ code = 0, stdout = argv[3] == "info=name" and "Test Vault" or root, stderr = "" })
    elseif argv[2] == "properties" then
      properties_calls = properties_calls + 1
      local output = properties_calls == 1 and "{}" or '{"status":"changed"}'
      callback({ code = 0, stdout = output, stderr = "" })
    elseif argv[2] == "property:set" then
      set_calls = set_calls + 1
    end
  end)
  workflow.start()
  MiniTest.expect.equality(properties_calls, 2)
  MiniTest.expect.equality(set_calls, 0)

  date_picker.pick = function(_, callback)
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "changed while calendar was open" })
    callback({ action = "select", value = "2026-08-21" })
  end
  properties_calls = 0
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "vault" then
      callback({ code = 0, stdout = argv[3] == "info=name" and "Test Vault" or root, stderr = "" })
    elseif argv[2] == "properties" then
      properties_calls = properties_calls + 1
      callback({ code = 0, stdout = "{}", stderr = "" })
    elseif argv[2] == "property:set" then
      set_calls = set_calls + 1
    end
  end)
  workflow.start()
  MiniTest.expect.equality(properties_calls, 1)
  MiniTest.expect.equality(set_calls, 0)
end

return T
