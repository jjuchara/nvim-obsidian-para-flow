local cli = require("obsidian-para-flow.cli")
local merge_transaction = require("obsidian-para-flow.merge_transaction")

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

local options = {
  target = "1. Projects/Note.md",
  source = "6. Inbox/Note.md",
  target_snapshot = "old target",
  content = "merged",
}

T["writes the target before trashing the Inbox source"] = function()
  local calls = {}
  cli._set_executor(function(argv, _, callback)
    table.insert(calls, argv)
    callback({ code = 0, stdout = "", stderr = "" })
  end)
  local result
  merge_transaction.execute("Vault", options, function(value)
    result = value
  end)

  MiniTest.expect.equality(result.ok, true)
  MiniTest.expect.equality({ calls[1][2], calls[2][2] }, { "create", "delete" })
  MiniTest.expect.equality(calls[1][3], "path=1. Projects/Note.md")
  MiniTest.expect.equality(calls[2][3], "path=6. Inbox/Note.md")
end

T["restores the target when trashing the source fails"] = function()
  local calls = {}
  cli._set_executor(function(argv, _, callback)
    table.insert(calls, argv[2])
    if argv[2] == "delete" then
      callback({ code = 2, stdout = "", stderr = "trash failed" })
    else
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end)
  local result
  merge_transaction.execute("Vault", options, function(value)
    result = value
  end)

  MiniTest.expect.equality(calls, { "create", "delete", "create" })
  MiniTest.expect.equality(result.kind, "rolled_back")
  MiniTest.expect.equality(result.message, "trash failed")
end

T["restores the target after an unsuccessful write attempt"] = function()
  local writes = 0
  cli._set_executor(function(_, _, callback)
    writes = writes + 1
    if writes == 1 then
      callback({ code = 2, stdout = "", stderr = "write failed" })
    else
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end)
  local result
  merge_transaction.execute("Vault", options, function(value)
    result = value
  end)

  MiniTest.expect.equality(writes, 2)
  MiniTest.expect.equality(result.kind, "rolled_back")
  MiniTest.expect.equality(result.message, "write failed")
end

T["reports an incomplete target rollback"] = function()
  local writes = 0
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "create" then
      writes = writes + 1
    end
    if writes == 1 then
      callback({ code = 2, stdout = "", stderr = "write failed" })
    else
      callback({ code = 2, stdout = "", stderr = "restore failed" })
    end
  end)
  local result
  merge_transaction.execute("Vault", options, function(value)
    result = value
  end)

  MiniTest.expect.equality(result.kind, "rollback")
  MiniTest.expect.equality(result.recovery.target, options.target)
  MiniTest.expect.equality(result.recovery.source, options.source)
  MiniTest.expect.equality(result.recovery.rollback_failure, "restore failed")
end

T["trashes multiple sources in order after writing the target"] = function()
  local calls = {}
  cli._set_executor(function(argv, _, callback)
    table.insert(calls, { argv[2], argv[3] })
    callback({ code = 0, stdout = "", stderr = "" })
  end)
  local result
  merge_transaction.execute("Vault", {
    target = options.target,
    sources = { "Source A.md", "Source B.md" },
    target_snapshot = options.target_snapshot,
    content = options.content,
  }, function(value)
    result = value
  end)

  MiniTest.expect.equality(calls, {
    { "create", "path=1. Projects/Note.md" },
    { "delete", "path=Source A.md" },
    { "delete", "path=Source B.md" },
  })
  MiniTest.expect.equality(result.ok, true)
  MiniTest.expect.equality(result.sources, { "Source A.md", "Source B.md" })
end

T["reports sources already trashed when a later source fails"] = function()
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "delete" and argv[3] == "path=Source B.md" then
      callback({ code = 2, stdout = "", stderr = "trash failed" })
    else
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end)
  local result
  merge_transaction.execute("Vault", {
    target = options.target,
    sources = { "Source A.md", "Source B.md", "Source C.md" },
    target_snapshot = options.target_snapshot,
    content = options.content,
  }, function(value)
    result = value
  end)

  MiniTest.expect.equality(result.kind, "rollback")
  MiniTest.expect.equality(result.recovery.target_state, "restored from the pre-merge snapshot")
  MiniTest.expect.equality(result.recovery.sources, {
    { path = "Source A.md", status = "trashed" },
    { path = "Source B.md", status = "trash failed" },
    { path = "Source C.md", status = "not attempted" },
  })
end

return T
