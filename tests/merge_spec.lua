local merge = require("obsidian-para-flow.merge")

local T = MiniTest.new_set()

T["orders the target first and composes named Markdown blocks"] = function()
  local content, ordered = merge.compose({
    target = "3. Resources/Target.md",
    notes = {
      {
        path = "6. Inbox/Source.md",
        content = "---\ntags: [source]\n---\n# Source title\n\nSource body\n",
        properties = { area = "[[Area]]", tags = { "shared", "source" } },
      },
      {
        path = "3. Resources/Target.md",
        content = "---\nstatus: Active\n---\n# Target title\n\nTarget body\n",
        properties = { area = "", status = "Active", tags = { "#shared", "target" } },
      },
    },
  })

  MiniTest.expect.equality(
    vim.tbl_map(function(note)
      return note.path
    end, ordered),
    { "3. Resources/Target.md", "6. Inbox/Source.md" }
  )
  MiniTest.expect.equality(
    content,
    table.concat({
      "---",
      'area: "[[Area]]"',
      'status: "Active"',
      'tags: ["#shared","target","source"]',
      "---",
      "## Target",
      "",
      "# Target title",
      "",
      "Target body",
      "",
      "---",
      "",
      "## Source",
      "",
      "# Source title",
      "",
      "Source body",
      "",
    }, "\n")
  )
end

T["requires two notes and an explicit target"] = function()
  local content, message = merge.compose({
    target = "Missing.md",
    notes = { { path = "Only.md", content = "", properties = {} } },
  })
  MiniTest.expect.equality(content, nil)
  MiniTest.expect.equality(message, "The selected merge target is missing")

  content, message = merge.compose({
    target = "Only.md",
    notes = { { path = "Only.md", content = "", properties = {} } },
  })
  MiniTest.expect.equality(content, nil)
  MiniTest.expect.equality(message, "Select at least two notes to merge")
end

return T
