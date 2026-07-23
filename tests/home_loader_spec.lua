local helpers = require("tests.helpers.config")
local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local loader = require("obsidian-para-flow.home_loader")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      cli._reset()
      config._reset()
    end,
    post_case = function()
      cli._reset()
    end,
  },
})

T["loads one section through the CLI and applies semantic filtering"] = function()
  local cfg = config.setup(helpers.valid())
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "files" then
      callback({
        code = 0,
        stdout = "1. Projects/Active.md\n1. Projects/Support.md",
        stderr = "",
      })
    elseif argv[2] == "properties" then
      local tagged = argv[3]:find("Active", 1, true) ~= nil
      callback({
        code = 0,
        stdout = vim.json.encode(
          tagged and { tags = { "projects" }, status = "В работе" } or {}
        ),
        stderr = "",
      })
    elseif argv[2] == "file" then
      callback({ code = 0, stdout = "created 1000\nmodified 2000\nsize 20", stderr = "" })
    end
  end)

  local result
  loader.load_section(cfg, "projects", function(value)
    result = value
  end)
  MiniTest.expect.equality(result.ok, true)
  MiniTest.expect.equality(#result.data.items, 1)
  MiniTest.expect.equality(result.data.items[1].name, "Active")
end

T["bounds metadata concurrency and rejects unsafe paths"] = function()
  local cfg = config.setup(helpers.valid())
  local callbacks = {}
  local running = 0
  local maximum = 0
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "files" then
      local paths = {}
      for index = 1, 8 do
        table.insert(paths, ("3. Resources/%d.md"):format(index))
      end
      callback({ code = 0, stdout = table.concat(paths, "\n"), stderr = "" })
    elseif argv[2] == "properties" then
      running = running + 1
      maximum = math.max(maximum, running)
      table.insert(callbacks, function()
        running = running - 1
        callback({ code = 0, stdout = '{"tags":["resources"]}', stderr = "" })
      end)
    elseif argv[2] == "file" then
      callback({ code = 0, stdout = "created 1000\nmodified 2000", stderr = "" })
    end
  end)

  local result
  loader.load_section(cfg, "resources", function(value)
    result = value
  end)
  MiniTest.expect.equality(#callbacks, 6)
  local next_callback = 1
  while callbacks[next_callback] do
    callbacks[next_callback]()
    next_callback = next_callback + 1
  end
  MiniTest.expect.equality(maximum, 6)
  MiniTest.expect.equality(result.ok, true)
  MiniTest.expect.equality(#result.data.items, 8)

  cli._set_executor(function(argv, _, callback)
    if argv[2] == "files" then
      callback({ code = 0, stdout = "Other/escape.md", stderr = "" })
    end
  end)
  loader.load_section(cfg, "resources", function(value)
    result = value
  end)
  MiniTest.expect.equality(result.kind, "path")
end

return T
