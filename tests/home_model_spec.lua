local helpers = require("tests.helpers.config")
local config = require("obsidian-para-flow.config")
local model = require("obsidian-para-flow.home_model")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      config._reset()
    end,
  },
})

local function item(path, properties, created, modified)
  return {
    path = path,
    properties = properties or {},
    info = { created = created or 1, modified = modified or created or 1 },
  }
end

T["filters semantic PARA entries and orders project statuses"] = function()
  local cfg = config.setup(helpers.valid())
  local projects = model.build("projects", {
    item("1. Projects/planned.md", { tags = { "projects" }, status = "Планируется" }),
    item("1. Projects/support.md", { tags = { "project-support" } }),
    item("1. Projects/active.md", { tags = { "#projects" }, status = "В работе" }),
  }, cfg)
  MiniTest.expect.equality(
    vim.tbl_map(function(value)
      return value.name
    end, projects.items),
    { "active", "planned" }
  )

  local areas = model.build("areas", {
    item("2. Areas/Visible.md", { tags = { "area" }, listShow = true }),
    item("2. Areas/Hidden.md", { tags = { "area" }, listShow = false }),
  }, cfg)
  MiniTest.expect.equality(#areas.items, 1)
  MiniTest.expect.equality(areas.items[1].name, "Visible")
end

T["sorts previews and groups full resource and archive lists"] = function()
  local cfg = config.setup(helpers.valid())
  local resources = model.build("resources", {
    item("3. Resources/Old.md", { tags = { "resources" }, area = "[[Work]]" }, 1, 10),
    item("3. Resources/New.md", { tags = { "resources" }, area = "[[Home]]" }, 1, 20),
    item("3. Resources/Loose.md", { tags = { "resources" } }, 1, 15),
  }, cfg)
  MiniTest.expect.equality(resources.items[1].name, "New")
  MiniTest.expect.equality(
    vim.tbl_map(function(value)
      return value.name
    end, model.grouped(resources, "")),
    { "Loose", "New", "Old" }
  )
  MiniTest.expect.equality(#model.grouped(resources, "new"), 1)

  local archives = model.build("archives", {
    item("4. Archives/Projects/A.md", { archived = "2026-01-01" }, 1, 10),
    item("4. Archives/Resources/B.md", { archived = "2026-02-01" }, 1, 20),
  }, cfg)
  MiniTest.expect.equality(archives.items[1].name, "B")
  MiniTest.expect.equality(archives.groups[1].name, "Projects")
end

T["keeps Inbox FIFO and filters by name or path"] = function()
  local cfg = config.setup(helpers.valid())
  local inbox = model.build("inbox", {
    item("6. Inbox/Later.md", { created = "2026-07-22T11:00:00Z" }, 2),
    item("6. Inbox/Earlier.md", { created = "2026-07-22T10:00:00Z" }, 1),
  }, cfg)
  MiniTest.expect.equality(inbox.items[1].name, "Earlier")
  MiniTest.expect.equality(model.filter(inbox, "later")[1].name, "Later")
  MiniTest.expect.equality(#model.filter(inbox, "missing"), 0)
end

return T
