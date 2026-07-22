local helpers = require("tests.helpers.config")
local config = require("obsidian-para-flow.config")
local cli = require("obsidian-para-flow.cli")
local inbox = require("obsidian-para-flow.inbox")
local ui = require("obsidian-para-flow.ui")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      config._reset()
      cli._reset()
      ui._reset()
      config.setup(helpers.valid())
      ui._set_input(function(_, callback)
        callback("New")
      end)
    end,
    post_case = function()
      cli._reset()
      ui._reset()
    end,
  },
})

T["discovers exactly the newly created safe Inbox files"] = function()
  local created = inbox._discover_created(
    { "6. Inbox/old.md" },
    { "6. Inbox/old.md", "6. Inbox/new.md", "Other/ignore.md", "6. Inbox/image.png" },
    "6. Inbox"
  )
  MiniTest.expect.equality(created, { "6. Inbox/new.md" })
end

T["positions after frontmatter and the first H1"] = function()
  local fixture = vim.fn.readfile("tests/fixtures/inbox/basic.md")
  MiniTest.expect.equality(inbox._find_body_line(fixture), 5)
  MiniTest.expect.equality(inbox._find_body_line({ "# Note", "body" }), 2)
  MiniTest.expect.equality(inbox._find_body_line({ "plain body" }), 1)
end

T["finds an unrendered Templater cursor marker"] = function()
  MiniTest.expect.equality(
    inbox._find_templater_cursor({
      "# Note",
      "prefix <% tp.file.cursor() %> suffix",
    }),
    {
      line = 2,
      column = 7,
      end_column = 29,
    }
  )
  MiniTest.expect.equality(inbox._find_templater_cursor({ "# Note", "body" }), nil)
end

T["validates terminal titles and derives the target path"] = function()
  MiniTest.expect.equality({ inbox._validate_title("  New note  ") }, { "New note" })
  MiniTest.expect.equality(
    { inbox._validate_title("") },
    { nil, "Inbox note title cannot be empty" }
  )
  MiniTest.expect.equality(inbox._validate_title("nested/note"), nil)
  MiniTest.expect.equality(inbox._target_path("6. Inbox", "New note"), "6. Inbox/New note.md")
  MiniTest.expect.equality(inbox._target_path("6. Inbox/", "New.md"), "6. Inbox/New.md")
end

local function executor_for(after_files, quickadd_output, vault_root)
  local files_calls = 0
  return function(argv, _, callback)
    local command = argv[3]
    if command == "files" then
      files_calls = files_calls + 1
      local output = files_calls == 1 and "6. Inbox/old.md" or table.concat(after_files, "\n")
      callback({ code = 0, stdout = output, stderr = "" })
    elseif command == "quickadd" then
      callback({ code = 0, stdout = quickadd_output, stderr = "" })
    elseif command == "vault" then
      local output = argv[4] == "info=name" and "Test Vault" or vault_root
      callback({ code = 0, stdout = output, stderr = "" })
    end
  end
end

T["opens the one created note and positions the cursor"] = function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/6. Inbox", "p")
  local path = root .. "/6. Inbox/new.md"
  vim.fn.writefile({ "---", "created: now", "---", "# New", "", "Text" }, path)
  cli._set_executor(
    executor_for(
      { "6. Inbox/old.md", "6. Inbox/new.md" },
      '{"ok":true,"choice":{"name":"inbox"}}',
      root
    )
  )

  inbox.new()

  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.fn.resolve(path))
  MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0), { 5, 0 })
  vim.cmd("bwipeout!")
end

T["consumes a Templater cursor marker and positions the cursor in Neovim"] = function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/6. Inbox", "p")
  local path = root .. "/6. Inbox/new.md"
  vim.fn.writefile({ "---", "created: now", "---", "# New", "", "<% tp.file.cursor() %>" }, path)
  cli._set_executor(
    executor_for(
      { "6. Inbox/old.md", "6. Inbox/new.md" },
      '{"ok":true,"choice":{"name":"inbox"}}',
      root
    )
  )

  inbox.new()

  MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0), { 6, 0 })
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 5, 6, false), { "" })
  MiniTest.expect.equality(vim.bo.modified, true)
  vim.cmd("bwipeout!")
end

T["does not open a file for cancellation zero ambiguous or CLI error results"] = function()
  local original = vim.api.nvim_buf_get_name(0)
  local notifications = {}
  local old_notify = vim.notify
  vim.notify = function(message)
    table.insert(notifications, message)
  end

  cli._set_executor(
    executor_for(
      { "6. Inbox/old.md" },
      '{"ok":false,"aborted":true,"error":"cancelled"}',
      "/unused"
    )
  )
  inbox.new()
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), original)

  cli._set_executor(
    executor_for({ "6. Inbox/old.md" }, '{"ok":true,"choice":{"name":"inbox"}}', "/unused")
  )
  inbox.new()
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), original)

  cli._set_executor(
    executor_for(
      { "6. Inbox/old.md", "6. Inbox/a.md", "6. Inbox/b.md" },
      '{"ok":true,"choice":{"name":"inbox"}}',
      "/unused"
    )
  )
  inbox.new()
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), original)

  local files_returned = false
  cli._set_executor(function(argv, _, callback)
    if argv[3] == "vault" then
      callback({ code = 0, stdout = "Test Vault", stderr = "" })
    elseif argv[3] == "files" and not files_returned then
      files_returned = true
      callback({ code = 0, stdout = "6. Inbox/old.md", stderr = "" })
    elseif argv[3] == "quickadd" then
      callback({ code = 2, stdout = "", stderr = "QuickAdd failed" })
    end
  end)
  inbox.new()
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), original)
  MiniTest.expect.equality(#notifications, 3)
  vim.notify = old_notify
end

T["collects the title in Neovim and runs QuickAdd without application UI"] = function()
  local quickadd_argv
  ui._set_input(function(options, callback)
    MiniTest.expect.equality(options.prompt, "Inbox note title: ")
    callback("Terminal title")
  end)
  cli._set_executor(function(argv, _, callback)
    if argv[3] == "vault" then
      callback({ code = 0, stdout = "Test Vault", stderr = "" })
    elseif argv[3] == "files" then
      callback({ code = 0, stdout = "6. Inbox/old.md", stderr = "" })
    elseif argv[3] == "quickadd" then
      quickadd_argv = argv
      callback({ code = 2, stdout = "", stderr = "stop after argv capture" })
    end
  end)

  inbox.new()

  MiniTest.expect.equality(quickadd_argv, {
    "obsidian",
    "vault=Test Vault",
    "quickadd",
    "choice=inbox",
    "value-title=Terminal title",
    "value-value=Terminal title",
  })
end

T["cancels before CLI work and rejects an existing title"] = function()
  local executions = 0
  ui._set_input(function(_, callback)
    callback(nil)
  end)
  cli._set_executor(function()
    executions = executions + 1
  end)
  inbox.new()
  MiniTest.expect.equality(executions, 0)

  ui._set_input(function(_, callback)
    callback("Existing")
  end)
  cli._set_executor(function(argv, _, callback)
    executions = executions + 1
    if argv[3] == "vault" then
      callback({ code = 0, stdout = "Test Vault", stderr = "" })
    elseif argv[3] == "files" then
      callback({ code = 0, stdout = "6. Inbox/existing.md", stderr = "" })
    end
  end)
  inbox.new()
  MiniTest.expect.equality(executions, 2)
end

T["sorts Inbox FIFO by metadata fallback and path"] = function()
  local notes = {
    { path = "6. Inbox/c.md", properties = {}, file_created = 30 },
    {
      path = "6. Inbox/b.md",
      properties = { created = "1970-01-01T00:00:10Z" },
      file_created = 50,
    },
    { path = "6. Inbox/a.md", properties = { created = "invalid" }, file_created = 30 },
  }
  inbox._sort_notes(notes)
  MiniTest.expect.equality(
    vim.tbl_map(function(note)
      return note.path
    end, notes),
    { "6. Inbox/b.md", "6. Inbox/a.md", "6. Inbox/c.md" }
  )
end

T["loads safe Inbox paths with properties and file creation time"] = function()
  cli._set_executor(function(argv, _, callback)
    if argv[3] == "files" then
      callback({ code = 0, stdout = "6. Inbox/B.md\n6. Inbox/A.md", stderr = "" })
    elseif argv[3] == "properties" then
      local created = argv[4]:match("A%.md") and "1970-01-01T00:00:01Z" or ""
      callback({ code = 0, stdout = vim.json.encode({ created = created }), stderr = "" })
    elseif argv[3] == "file" then
      local created = argv[4]:match("A%.md") and 5000 or 2000
      callback({ code = 0, stdout = "path x\ncreated " .. created, stderr = "" })
    end
  end)

  local result
  inbox.load(function(value)
    result = value
  end)
  MiniTest.expect.equality(result.ok, true)
  MiniTest.expect.equality(result.data[1].path, "6. Inbox/A.md")
  MiniTest.expect.equality(result.data[1].file_created, 5)
  MiniTest.expect.equality(result.data[2].path, "6. Inbox/B.md")
end

T["rejects unsafe paths returned by the Inbox listing"] = function()
  cli._set_executor(function(_, _, callback)
    callback({ code = 0, stdout = "Other/note.md", stderr = "" })
  end)
  local result
  inbox.load(function(value)
    result = value
  end)
  MiniTest.expect.equality({ result.ok, result.kind }, { false, "path" })
end

return T
