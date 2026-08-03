local helpers = require("tests.helpers.config")
local plugin = require("obsidian-para-flow")

local function read_file(path)
  local file = assert(io.open(path, "r"))
  local content = file:read("*a")
  file:close()
  return content
end

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
  second.mappings = {
    home = "<leader>oz",
    daily = "<leader>oy",
    new = "<leader>ox",
    review = false,
  }
  plugin.setup(second)

  MiniTest.expect.equality(vim.fn.maparg("<leader>on", "n"), "")
  MiniTest.expect.no_equality(vim.fn.maparg("<leader>ox", "n"), "")
  MiniTest.expect.no_equality(vim.fn.maparg("<leader>oz", "n"), "")
  MiniTest.expect.no_equality(vim.fn.maparg("<leader>oy", "n"), "")
  MiniTest.expect.equality(
    vim.fn.maparg("<leader>ox", "n", false, true).desc,
    "Obsidian PARA: new Inbox note"
  )
  MiniTest.expect.equality(
    vim.fn.maparg("<leader>om", "n", false, true).desc,
    "Obsidian PARA: edit note metadata"
  )
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaInboxNew"), 2)
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaInboxNewWithTask"), 2)
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaCapture"), 2)
  MiniTest.expect.equality(vim.fn.maparg("<leader>oN", "n"), "")
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaInboxReview"), 2)
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaArchiveReview"), 2)
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaMetadata"), 2)
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaSetDateProperty"), 2)
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaHome"), 2)
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaHealth"), 2)
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaFind"), 2)
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaGrep"), 2)
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaTags"), 2)
  MiniTest.expect.equality(vim.fn.exists(":ObsidianParaDaily"), 2)
end

T["installs the find prefix and removes it when disabled"] = function()
  plugin.setup(helpers.valid())
  for _, key in ipairs({ "ff", "fi", "fp", "fa", "fr", "fx", "fg", "fG", "ft" }) do
    MiniTest.expect.no_equality(vim.fn.maparg("<leader>o" .. key, "n"), "")
  end
  MiniTest.expect.equality(
    vim.fn.maparg("<leader>ofr", "n", false, true).desc,
    "Obsidian PARA: find notes in resources"
  )

  local disabled = helpers.valid()
  disabled.mappings = { find = false }
  plugin.setup(disabled)
  MiniTest.expect.equality(vim.fn.maparg("<leader>off", "n"), "")
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
    {
      "<leader>of",
      group = "find",
      icon = { icon = "󰍉 ", color = "purple" },
    },
  })
end

T["keeps stable commands and Lua API documented"] = function()
  plugin._register_commands()
  local readme = read_file("README.md")
  local help = read_file("doc/obsidian-para-flow.txt")

  for _, command in ipairs({
    "ObsidianParaHome",
    "ObsidianParaFind",
    "ObsidianParaGrep",
    "ObsidianParaTags",
    "ObsidianParaInboxNew",
    "ObsidianParaInboxNewWithTask",
    "ObsidianParaCapture",
    "ObsidianParaInboxReview",
    "ObsidianParaArchiveReview",
    "ObsidianParaMetadata",
    "ObsidianParaSetDateProperty",
    "ObsidianParaHealth",
    "ObsidianParaDaily",
  }) do
    MiniTest.expect.equality(vim.fn.exists(":" .. command), 2)
    MiniTest.expect.no_equality(readme:find(":" .. command, 1, true), nil)
    MiniTest.expect.no_equality(help:find(":" .. command, 1, true), nil)
  end

  for _, name in ipairs({
    "setup",
    "home",
    "inbox_new",
    "inbox_new_with_task",
    "capture",
    "inbox_review",
    "archive_review",
    "metadata",
    "set_date_property",
    "find",
    "grep",
    "tags",
    "health",
    "daily",
  }) do
    MiniTest.expect.equality(type(plugin[name]), "function")
    MiniTest.expect.no_equality(readme:find(name .. "(", 1, true), nil)
    MiniTest.expect.no_equality(help:find(name .. "(", 1, true), nil)
  end
end

return T
