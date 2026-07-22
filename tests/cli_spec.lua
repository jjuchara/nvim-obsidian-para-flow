local cli = require("obsidian-para-flow.cli")

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

T["passes user values as individual argv entries"] = function()
  local captured
  cli._set_executor(function(argv, _, callback)
    captured = argv
    callback({ code = 0, stdout = "ok\n", stderr = "" })
  end)

  local result
  cli.move("Vault; touch nope", "Inbox/a note.md", "1. Projects/$HOME", function(value)
    result = value
  end)

  MiniTest.expect.equality(captured, {
    "obsidian",
    "vault=Vault; touch nope",
    "move",
    "path=Inbox/a note.md",
    "to=1. Projects/$HOME",
  })
  MiniTest.expect.equality(result.ok, true)
end

T["normalizes spawn timeout exit and unavailable failures"] = function()
  local cases = {
    { raw = { spawn_error = "ENOENT" }, kind = "spawn" },
    { raw = { code = 124, stdout = "", stderr = "" }, kind = "timeout" },
    { raw = { code = 2, stdout = "", stderr = "bad" }, kind = "exit" },
    {
      raw = { code = 1, stdout = "", stderr = "The CLI is unable to find Obsidian" },
      kind = "unavailable",
    },
  }

  for _, case in ipairs(cases) do
    cli._set_executor(function(_, _, callback)
      callback(case.raw)
    end)
    local result
    cli.run("Vault", "version", nil, function(value)
      result = value
    end, { auto_start = false })
    MiniTest.expect.equality(result.kind, case.kind)
  end
end

T["starts Obsidian once waits for readiness and retries the original command"] = function()
  local executions = 0
  local launched_vault
  cli._set_executor(function(_, _, callback)
    executions = executions + 1
    if executions == 1 then
      callback({ code = 1, stdout = "", stderr = "The CLI is unable to find Obsidian" })
    else
      callback({ code = 0, stdout = "1.12.7", stderr = "" })
    end
  end)
  cli._set_launcher(function(vault, callback)
    launched_vault = vault
    callback(true)
  end)
  cli._set_defer(function(callback)
    callback()
  end)

  local result
  cli.version("Test Vault", function(value)
    result = value
  end)

  MiniTest.expect.equality(launched_vault, "Test Vault")
  MiniTest.expect.equality(executions, 3)
  MiniTest.expect.equality(result.ok, true)
end

T["reports launcher failure without retrying the command"] = function()
  local executions = 0
  cli._set_executor(function(_, _, callback)
    executions = executions + 1
    callback({ code = 1, stdout = "", stderr = "The CLI is unable to find Obsidian" })
  end)
  cli._set_launcher(function(_, callback)
    callback(false, "no URI handler")
  end)

  local result
  cli.version("Test Vault", function(value)
    result = value
  end)

  MiniTest.expect.equality(executions, 1)
  MiniTest.expect.equality(result.kind, "launch")
  MiniTest.expect.equality(result.message, "no URI handler")
end

T["fails closed when Obsidian resolves another vault"] = function()
  cli._set_executor(function(_, _, callback)
    callback({ code = 0, stdout = "Production Vault", stderr = "" })
  end)

  local result
  cli.ensure_vault("Test Vault", function(value)
    result = value
  end)

  MiniTest.expect.equality(result.ok, false)
  MiniTest.expect.equality(result.kind, "vault")
end

T["parses QuickAdd success cancellation and malformed output"] = function()
  local outputs = {
    { stdout = '{"ok":true,"choice":{"name":"inbox"}}', expected = { true, nil } },
    {
      stdout = '{"ok":false,"aborted":true,"error":"cancelled"}',
      expected = { false, "canceled" },
    },
    { stdout = "not-json", expected = { false, "output" } },
  }

  for _, item in ipairs(outputs) do
    local argv
    cli._set_executor(function(value, _, callback)
      argv = value
      callback({ code = 0, stdout = item.stdout, stderr = "" })
    end)
    local result
    cli.quickadd("Vault", "inbox", { title = "New note" }, function(value)
      result = value
    end)
    MiniTest.expect.equality({ result.ok, result.kind }, item.expected)
    MiniTest.expect.equality(argv[5], "value-title=New note")
  end
end

T["reads notes without frontmatter as empty properties"] = function()
  local cases = {
    { stdout = "No frontmatter found.", expected = { true, {} } },
    { stdout = "", expected = { true, {} } },
    { stdout = "not json", expected = { false, nil } },
    { stdout = '{"status":"Plan"}', expected = { true, { status = "Plan" } } },
  }

  for _, case in ipairs(cases) do
    cli._set_executor(function(_, _, callback)
      callback({ code = 0, stdout = case.stdout, stderr = "" })
    end)

    local result
    cli.properties("V", "1. Projects/README.md", function(value)
      result = value
    end)

    MiniTest.expect.equality({ result.ok, result.data }, case.expected)
  end
end

T["centralizes read and mutation command contracts"] = function()
  local commands = {}
  cli._set_executor(function(argv, _, callback)
    table.insert(commands, argv[3])
    local stdout = argv[3] == "properties" and "{}" or ""
    callback({ code = 0, stdout = stdout, stderr = "" })
  end)
  local done = function() end

  cli.read("V", "a.md", done)
  cli.properties("V", "a.md", done)
  cli.property_set("V", "a.md", "status", "Plan", "text", done)
  cli.property_remove("V", "a.md", "status", done)
  cli.move("V", "a.md", "folder/a.md", done)
  cli.rename("V", "a.md", "b", done)
  cli.create("V", "new.md", "body", done)
  cli.write("V", "a.md", "body", done)
  cli.trash("V", "a.md", done)

  MiniTest.expect.equality(commands, {
    "read",
    "properties",
    "property:set",
    "property:remove",
    "move",
    "rename",
    "create",
    "create",
    "delete",
  })
end

T["keeps fixture creation non-destructive and existing writes explicit"] = function()
  local calls = {}
  cli._set_executor(function(argv, _, callback)
    table.insert(calls, argv)
    callback({ code = 0, stdout = "", stderr = "" })
  end)

  cli.create("V", "new.md", "new", function() end)
  cli.write("V", "existing.md", "replacement", function() end)

  MiniTest.expect.equality(calls[1], {
    "obsidian",
    "vault=V",
    "create",
    "path=new.md",
    "content=new",
  })
  MiniTest.expect.equality(calls[2][6], "overwrite")
end

T["parses file metadata and rejects a missing creation time"] = function()
  cli._set_executor(function(_, _, callback)
    callback({
      code = 0,
      stdout = "path 6. Inbox/A note.md\nname A note\nextension md\nsize 12\ncreated 1700000000123\nmodified 1700000000456",
      stderr = "",
    })
  end)
  local result
  cli.file_info("V", "6. Inbox/A note.md", function(value)
    result = value
  end)
  MiniTest.expect.equality(result.data.path, "6. Inbox/A note.md")
  MiniTest.expect.equality(result.data.created, 1700000000123)

  cli._set_executor(function(_, _, callback)
    callback({ code = 0, stdout = "path Note.md", stderr = "" })
  end)
  cli.file_info("V", "Note.md", function(value)
    result = value
  end)
  MiniTest.expect.equality({ result.ok, result.kind }, { false, "output" })
end

return T
