local helpers = require("tests.helpers.config")
local plugin = require("obsidian-para-flow")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      plugin._reset()
    end,
  },
})

T["setup can be called repeatedly without duplicate mappings or commands"] = function()
  local first = helpers.valid()
  plugin.setup(first)

  local second = helpers.valid()
  second.mappings = { new = "<leader>ox", review = false }
  plugin.setup(second)

  MiniTest.expect.equality(vim.fn.maparg("<leader>on", "n"), "")
  MiniTest.expect.no_equality(vim.fn.maparg("<leader>ox", "n"), "")
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaInboxNew"), 2)
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaInboxReview"), 2)
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaHealth"), 2)
end

T["registers the leader o group when WhichKey is available"] = function()
  local previous = package.loaded["which-key"]
  local received
  package.loaded["which-key"] = {
    add = function(spec)
      received = spec
    end,
  }

  plugin.setup(helpers.valid())
  package.loaded["which-key"] = previous

  -- selene: allow(mixed_table)
  MiniTest.expect.equality(received, {
    {
      "<leader>o",
      group = "obsidian para flow",
      icon = { icon = "◆ ", color = "purple" },
    },
  })
end

return T
