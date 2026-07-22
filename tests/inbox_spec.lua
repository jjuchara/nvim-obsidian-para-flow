local helpers = require("tests.helpers.config")
local config = require("obsidian-para-flow.config")
local cli = require("obsidian-para-flow.cli")
local inbox = require("obsidian-para-flow.inbox")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      config._reset()
      cli._reset()
      config.setup(helpers.valid())
    end,
    post_case = function()
      cli._reset()
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

return T
