local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local date_picker = require("obsidian-para-flow.date_picker")
local helpers = require("tests.helpers.config")
local ui = require("obsidian-para-flow.ui")
local vault = require("obsidian-para-flow.vault")
local workflow = require("obsidian-para-flow.add_property")

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
  return root
end

local function executor(root, property_output, calls)
  return function(argv, _, callback)
    calls[#calls + 1] = argv
    if argv[2] == "vault" then
      callback({ code = 0, stdout = argv[3] == "info=name" and "Test Vault" or root, stderr = "" })
    elseif argv[2] == "properties" and argv[3] == "counts" then
      callback({ code = 0, stdout = '{"deadline":2,"status":4}', stderr = "" })
    elseif argv[2] == "properties" then
      callback({ code = 0, stdout = property_output, stderr = "" })
    elseif argv[2] == "property:set" then
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end
end

T["selects a known property and preserves its existing non-date type"] = function()
  local root = open_note()
  local calls = {}
  ui._set_select(function(items, options, callback)
    MiniTest.expect.equality(items, { "deadline", "status" })
    MiniTest.expect.equality(options.prompt, "Property: ")
    callback("status")
  end)
  ui._set_input(function(options, callback)
    MiniTest.expect.equality(options, { prompt = "Set status: ", default = "Plan" })
    callback("Done")
  end)
  cli._set_executor(executor(root, '{"status":"Plan"}', calls))

  workflow.start()

  MiniTest.expect.equality(calls[#calls], {
    "obsidian",
    "property:set",
    "path=3. Resources/Note.md",
    "name=status",
    "value=Done",
    "vault=Test Vault",
  })
end

T["opens the calendar when the selected property is configured as a date"] = function()
  local root = open_note()
  local calls = {}
  ui._set_select(function(_, _, callback)
    callback("deadline")
  end)
  date_picker.pick = function(options, callback)
    MiniTest.expect.equality(options.initial, "2026-08-10")
    callback({ action = "select", value = "2026-08-20" })
  end
  cli._set_executor(executor(root, '{"deadline":"2026-08-10"}', calls))

  workflow.start()

  MiniTest.expect.equality(calls[#calls], {
    "obsidian",
    "property:set",
    "path=3. Resources/Note.md",
    "name=deadline",
    "value=2026-08-20",
    "type=date",
    "vault=Test Vault",
  })
end

return T
