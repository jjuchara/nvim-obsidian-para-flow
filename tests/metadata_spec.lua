local metadata = require("obsidian-para-flow.metadata")

local T = MiniTest.new_set()

T["parses supported created values and rejects invalid dates"] = function()
  MiniTest.expect.equality(metadata.parse_created("1970-01-01T00:00:00Z"), 0)
  MiniTest.expect.equality(metadata.parse_created("1970-01-01T03:00:00+03:00"), 0)
  MiniTest.expect.equality(metadata.parse_created("1970-01-01T00:00:00.123Z"), 0)
  MiniTest.expect.equality(metadata.parse_created("2024-02-30"), nil)
  MiniTest.expect.equality(metadata.parse_created("not a date"), nil)

  local local_value = metadata.parse_created("22.07.2026 14:30")
  local parts = os.date("*t", local_value)
  MiniTest.expect.equality(
    { parts.year, parts.month, parts.day, parts.hour, parts.min },
    { 2026, 7, 22, 14, 30 }
  )
  MiniTest.expect.equality(
    metadata.parse_created("2026-07-22"),
    os.time({
      year = 2026,
      month = 7,
      day = 22,
      hour = 0,
      min = 0,
      sec = 0,
    })
  )
end

T["normalizes PARA metadata without overwriting existing values"] = function()
  local para = {
    projects = { link = "[[My Projects]]" },
    areas = { link = "[[My Areas]]" },
  }
  local cases = {
    {
      category = "projects",
      context = { created = "2026-07-22T10:00:00", area = "[[Work]]" },
      expected = {
        tags = { "existing", "projects" },
        created = "2026-07-22T10:00:00",
        links = "[[My Projects]]",
        area = "[[Work]]",
        status = "Планируется",
      },
    },
    {
      category = "areas",
      context = { created = "2026-07-22T10:00:00" },
      expected = {
        tags = { "existing", "area" },
        created = "2026-07-22T10:00:00",
        links = "[[My Areas]]",
        listShow = true,
      },
    },
    {
      category = "resources",
      context = { created = "2026-07-22T10:00:00", area = "[[Work]]" },
      expected = {
        tags = { "existing", "resources" },
        created = "2026-07-22T10:00:00",
        area = "[[Work]]",
      },
    },
    {
      category = "archives",
      context = {
        created = "2026-07-22T10:00:00",
        archived = "2026-07-22",
        archive_reason = "Done",
      },
      expected = {
        tags = { "existing" },
        created = "2026-07-22T10:00:00",
        archived = "2026-07-22",
        archive_reason = "Done",
      },
    },
  }

  for _, case in ipairs(cases) do
    local result = metadata.normalize(case.category, { tags = { "existing" } }, case.context, para)
    MiniTest.expect.equality(result.metadata, case.expected)
    MiniTest.expect.equality(result.missing, {})
  end

  local preserved = metadata.normalize("projects", {
    tags = { "#projects" },
    created = "old",
    links = "custom",
    area = "[[Existing]]",
    status = "Active",
  }, {}, para)
  MiniTest.expect.equality(preserved.metadata, {
    tags = { "#projects" },
    created = "old",
    links = "custom",
    area = "[[Existing]]",
    status = "Active",
  })
  MiniTest.expect.equality(preserved.additions, {})
end

T["reports required interactive values before building a mutation plan"] = function()
  local para = {
    projects = { link = "[[My Projects]]" },
    areas = { link = "[[My Areas]]" },
  }
  local project = metadata.normalize("projects", {}, { created = "now" }, para)
  MiniTest.expect.equality(project.missing, { "area" })

  local archive = metadata.normalize("archives", {}, {}, para)
  MiniTest.expect.equality(archive.missing, { "archive_reason", "created", "archived" })

  local plan = metadata.operation_plan(
    "6. Inbox/Note.md",
    "1. Projects/Note.md",
    "projects",
    { tags = { "old" } },
    { created = "now", area = "[[Work]]" },
    para
  )
  MiniTest.expect.equality(plan.preflight.missing, {})
  MiniTest.expect.equality(plan.snapshot, { tags = { "old" } })
  MiniTest.expect.equality(plan.move.destination, "1. Projects/Note.md")
  local tag_compensation
  for _, step in ipairs(plan.compensate) do
    if step.name == "tags" then
      tag_compensation = step
    end
  end
  MiniTest.expect.equality(tag_compensation, {
    action = "set",
    name = "tags",
    value = { "old" },
    type = "list",
  })
end

return T
