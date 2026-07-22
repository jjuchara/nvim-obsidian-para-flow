local conflict = require("obsidian-para-flow.conflict")

local T = MiniTest.new_set()

T["validates and normalizes conflict rename input"] = function()
  MiniTest.expect.equality({ conflict.normalize_name(" Renamed ") }, { "Renamed.md" })
  MiniTest.expect.equality({ conflict.normalize_name("Renamed.md") }, { "Renamed.md" })
  for _, value in ipairs({ "", ".", "..", "folder/name", "folder\\name" }) do
    local name, error_message = conflict.normalize_name(value)
    MiniTest.expect.equality(name, nil)
    MiniTest.expect.equality(type(error_message), "string")
  end
end

T["composes target-first metadata and bodies without a duplicate H1"] = function()
  local content = conflict.compose({
    category = "projects",
    context = { created = "2026-07-22T10:00:00", area = "[[2. Areas/Work]]" },
    para = { projects = { link = "[[My Projects]]" } },
    target_properties = {
      created = "2020-01-01",
      status = "Active",
      tags = { "shared", "target" },
    },
    source_properties = {
      status = "Inbox status",
      tags = { "#shared", "source" },
      source_only = "kept",
    },
    target_content = "---\nstatus: Active\n---\n# Same\n\nTarget body\n",
    source_content = "---\ntags: [source]\n---\n# Same\n\nInbox body\n",
  })

  MiniTest.expect.equality(
    content,
    table.concat({
      "---",
      'area: "[[2. Areas/Work]]"',
      'created: "2020-01-01"',
      'links: "[[My Projects]]"',
      'source_only: "kept"',
      'status: "Active"',
      'tags: ["shared","target","source","projects"]',
      "---",
      "# Same",
      "",
      "Target body",
      "",
      "---",
      "",
      "Inbox body",
      "",
    }, "\n")
  )
end

T["preserves a different Inbox H1"] = function()
  local content = conflict.compose({
    category = "areas",
    context = { created = "2026-07-22T10:00:00" },
    para = { areas = { link = "[[My Areas]]" } },
    target_properties = {},
    source_properties = {},
    target_content = "# Target\n",
    source_content = "# Source\n",
  })
  MiniTest.expect.equality(content:find("# Source", 1, true) ~= nil, true)
end

return T
