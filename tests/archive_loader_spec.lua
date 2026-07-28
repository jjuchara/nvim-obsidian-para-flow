local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local helpers = require("tests.helpers.config")
local loader = require("obsidian-para-flow.archive_loader")

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

T["loads overdue projects and opt-in notes while excluding archives"] = function()
  local cfg = config.setup(helpers.valid())
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "vault" then
      callback({ code = 0, stdout = "Test Vault", stderr = "" })
    elseif argv[2] == "files" then
      callback({
        code = 0,
        stdout = table.concat({
          "1. Projects/Late.md",
          "2. Areas/Review.md",
          "3. Resources/Invalid.md",
          "4. Archives/Projects/Old.md",
          "5. Daily/Today.md",
        }, "\n"),
        stderr = "",
      })
    elseif argv[2] == "properties" then
      local path = table.concat(argv, " ")
      local properties = path:find("Late.md", 1, true) and { deadline = "2020-01-01" }
        or path:find("Review.md", 1, true) and { expired_at = "2021-01-01" }
        or path:find("Invalid.md", 1, true) and { expired_at = "2021-99-01" }
        or {}
      callback({ code = 0, stdout = vim.json.encode(properties), stderr = "" })
    elseif argv[2] == "file" then
      callback({ code = 0, stdout = "created 1000\nmodified 2000\nsize 10", stderr = "" })
    end
  end)

  local result
  loader.load(cfg, function(value)
    result = value
  end)
  MiniTest.expect.equality(result.ok, true)
  MiniTest.expect.equality(
    vim.tbl_map(function(note)
      return note.path
    end, result.data),
    {
      "1. Projects/Late.md",
      "2. Areas/Review.md",
    }
  )
  MiniTest.expect.equality(result.data[1].expiration_property, "deadline")
  MiniTest.expect.equality(result.data[2].expiration_property, "expired_at")
  MiniTest.expect.equality(result.invalid, { "3. Resources/Invalid.md: invalid expired_at" })
end

T["fails closed when the active vault does not match"] = function()
  local cfg = config.setup(helpers.valid())
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "vault" then
      callback({ code = 0, stdout = "Production", stderr = "" })
    end
  end)
  local result
  loader.load(cfg, function(value)
    result = value
  end)
  MiniTest.expect.equality(result.kind, "vault")
end

return T
