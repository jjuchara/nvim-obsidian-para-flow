local cli = require("obsidian-para-flow.cli")
local transaction = require("obsidian-para-flow.transaction")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      cli._reset()
    end,
    post_case = function()
      cli._reset()
    end,
  },
})

local function plan()
  return {
    apply = {
      { name = "tags", value = { "old", "projects" }, type = "list" },
      { name = "status", value = "Планируется", type = "text" },
    },
    compensate = {
      { action = "remove", name = "status" },
      { action = "set", name = "tags", value = { "old" }, type = "list" },
    },
    move = { path = "6. Inbox/Note.md", destination = "1. Projects/Note.md" },
  }
end

T["applies properties in order and moves last"] = function()
  local calls = {}
  cli._set_executor(function(argv, _, callback)
    table.insert(calls, argv)
    callback({ code = 0, stdout = "", stderr = "" })
  end)
  local result

  transaction.execute("Vault", plan(), function(value)
    result = value
  end)

  MiniTest.expect.equality(result, { ok = true, destination = "1. Projects/Note.md" })
  MiniTest.expect.equality({ calls[1][3], calls[2][3], calls[3][3] }, {
    "property:set",
    "property:set",
    "move",
  })
  MiniTest.expect.equality(calls[1][6], 'value=["old","projects"]')
end

T["rolls back all applied properties after a move failure"] = function()
  local calls = {}
  cli._set_executor(function(argv, _, callback)
    table.insert(calls, argv[3] .. ":" .. (argv[5] or ""))
    if argv[3] == "move" then
      callback({ code = 2, stdout = "", stderr = "move failed" })
    else
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end)
  local result

  transaction.execute("Vault", plan(), function(value)
    result = value
  end)

  MiniTest.expect.equality(result.kind, "rolled_back")
  MiniTest.expect.equality(calls, {
    "property:set:name=tags",
    "property:set:name=status",
    "move:to=1. Projects/Note.md",
    "property:remove:name=status",
    "property:set:name=tags",
  })
  MiniTest.expect.equality(result.recovery.rollback_failures, {})
end

T["rolls back earlier properties when applying a later property fails"] = function()
  local sets = 0
  local commands = {}
  cli._set_executor(function(argv, _, callback)
    table.insert(commands, argv[3])
    if argv[3] == "property:set" then
      sets = sets + 1
    end
    if sets == 2 then
      callback({ code = 2, stdout = "", stderr = "set failed" })
    else
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end)
  local result

  transaction.execute("Vault", plan(), function(value)
    result = value
  end)

  MiniTest.expect.equality(result.kind, "rolled_back")
  MiniTest.expect.equality(commands, { "property:set", "property:set", "property:set" })
end

T["reports exact incomplete rollback details"] = function()
  cli._set_executor(function(argv, _, callback)
    if argv[3] == "move" then
      callback({ code = 2, stdout = "", stderr = "move failed" })
    elseif argv[3] == "property:remove" then
      callback({ code = 2, stdout = "", stderr = "remove failed" })
    else
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end)
  local result

  transaction.execute("Vault", plan(), function(value)
    result = value
  end)

  MiniTest.expect.equality(result.kind, "rollback")
  MiniTest.expect.equality(result.recovery.source, "6. Inbox/Note.md")
  MiniTest.expect.equality(result.recovery.destination, "1. Projects/Note.md")
  MiniTest.expect.equality(result.recovery.changed_properties, { "tags", "status" })
  MiniTest.expect.equality(result.recovery.rollback_failures, {
    { property = "status", action = "remove", message = "remove failed" },
  })
end

return T
