local helpers = require("tests.helpers.config")
local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local review = require("obsidian-para-flow.review")
local ui = require("obsidian-para-flow.ui")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      review._reset()
      cli._reset()
      ui._reset()
      config._reset()
      config.setup(helpers.valid())
    end,
    post_case = function()
      review._reset()
      cli._reset()
      ui._reset()
    end,
  },
})

local function executor(root, options)
  options = options or {}
  return function(argv, _, callback)
    local command = argv[2]
    if command == "files" then
      callback({ code = 0, stdout = options.files or "6. Inbox/First.md", stderr = "" })
    elseif command == "properties" then
      callback({ code = 0, stdout = '{"created":"2026-07-20"}', stderr = "" })
    elseif command == "file" then
      callback({ code = 0, stdout = "created 1000", stderr = "" })
    elseif command == "vault" then
      callback({ code = 0, stdout = options.vault_path or root, stderr = "" })
    elseif command == "folders" then
      callback({ code = 0, stdout = "", stderr = "" })
    elseif command == "delete" then
      if options.on_delete then
        options.on_delete(argv, callback)
      end
      if options.defer_delete then
        return
      end
      callback(options.delete_result or { code = 0, stdout = "", stderr = "" })
    end
  end
end

local function create_notes(root, names)
  vim.fn.mkdir(root .. "/6. Inbox", "p")
  for _, name in ipairs(names) do
    vim.fn.writefile({ "# " .. name, "", name .. " body" }, root .. "/6. Inbox/" .. name .. ".md")
  end
end

T["opens the oldest Inbox note as an editable Markdown buffer with persistent actions"] = function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/6. Inbox", "p")
  vim.fn.writefile({ "# First", "", "Body" }, root .. "/6. Inbox/First.md")
  cli._set_executor(executor(root))

  review.start()

  local active = review._current()
  MiniTest.expect.equality(active.session:current().path, "6. Inbox/First.md")
  MiniTest.expect.equality(
    vim.api.nvim_win_get_buf(active.view.windows.body),
    active.view.buffers.body
  )
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_name(active.view.buffers.body),
    vim.fn.resolve(root .. "/6. Inbox/First.md")
  )
  MiniTest.expect.equality(vim.bo[active.view.buffers.body].modifiable, true)
  MiniTest.expect.equality(vim.bo[active.view.buffers.body].readonly, false)
  MiniTest.expect.equality(vim.bo[active.view.buffers.body].filetype, "markdown")
  MiniTest.expect.equality(vim.fn.maparg("d", "n", false, true).buffer, 1)
  MiniTest.expect.equality(vim.fn.maparg("e", "n", false, true).buffer, 1)
  MiniTest.expect.equality(vim.fn.maparg("s", "n", false, true).buffer, 1)
  MiniTest.expect.equality(vim.fn.maparg("q", "n", false, true).buffer, 1)
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(active.view.buffers.status, 0, -1, false),
    { "Queue 1 / 1  ·  6. Inbox/First.md" }
  )
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(active.view.buffers.footer, 0, -1, false), {
    "[p] Project  [a] Area  [r] Resource  [x] Archive  [d] Trash  [e] Now  [s] Skip  [q] Quit",
  })
end

T["saves and skips to the next FIFO note"] = function()
  local root = vim.fn.tempname()
  create_notes(root, { "First", "Second" })
  cli._set_executor(executor(root, { files = "6. Inbox/First.md\n6. Inbox/Second.md" }))
  review.start()
  local active = review._current()
  local first_buffer = active.target.buffer
  vim.api.nvim_buf_set_lines(active.target.buffer, -1, -1, false, { "Edited" })

  review._action("skip")

  active = review._current()
  MiniTest.expect.equality(vim.fn.readfile(root .. "/6. Inbox/First.md"), {
    "# First",
    "",
    "First body",
    "Edited",
  })
  MiniTest.expect.equality(active.session:current().path, "6. Inbox/Second.md")
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_name(active.target.buffer),
    vim.fn.resolve(root .. "/6. Inbox/Second.md")
  )
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(active.view.buffers.status, 0, -1, false),
    { "Queue 2 / 2  ·  6. Inbox/Second.md" }
  )
  vim.api.nvim_buf_call(first_buffer, function()
    MiniTest.expect.equality(vim.fn.maparg("d", "n"), "")
    MiniTest.expect.equality(vim.fn.maparg("e", "n"), "")
    MiniTest.expect.equality(vim.fn.maparg("s", "n"), "")
    MiniTest.expect.equality(vim.fn.maparg("q", "n"), "")
  end)
  MiniTest.expect.equality(vim.fn.maparg("e", "n", false, true).buffer, 1)
end

T["moves a saved note to Obsidian trash and advances only after success"] = function()
  local root = vim.fn.tempname()
  create_notes(root, { "First", "Second" })
  local delete_argv
  cli._set_executor(executor(root, {
    files = "6. Inbox/First.md\n6. Inbox/Second.md",
    on_delete = function(argv)
      delete_argv = argv
    end,
  }))
  ui._set_select(function(items, options, callback)
    MiniTest.expect.equality(items, { "Cancel", "Move to trash" })
    MiniTest.expect.equality(options.prompt, "Move `6. Inbox/First.md` to the Obsidian trash?")
    callback("Move to trash")
  end)
  review.start()
  local active = review._current()
  local first_buffer = active.target.buffer
  vim.api.nvim_buf_set_lines(first_buffer, -1, -1, false, { "Saved before trash" })

  review._action("delete")

  MiniTest.expect.equality(delete_argv, {
    "obsidian",
    "delete",
    "path=6. Inbox/First.md",
    "vault=Test Vault",
  })
  MiniTest.expect.equality(vim.fn.readfile(root .. "/6. Inbox/First.md"), {
    "# First",
    "",
    "First body",
    "Saved before trash",
  })
  MiniTest.expect.equality(active.session:current().path, "6. Inbox/Second.md")
  MiniTest.expect.equality(active.session:snapshot().actions, { delete = 1 })
  vim.api.nvim_buf_call(first_buffer, function()
    MiniTest.expect.equality(vim.fn.maparg("d", "n"), "")
  end)
  MiniTest.expect.equality(vim.fn.maparg("d", "n", false, true).buffer, 1)
end

T["keeps the current note when trash confirmation is canceled"] = function()
  local root = vim.fn.tempname()
  create_notes(root, { "First" })
  local delete_called = false
  cli._set_executor(executor(root, {
    on_delete = function()
      delete_called = true
    end,
  }))
  ui._set_select(function(items, _, callback)
    MiniTest.expect.equality(items[1], "Cancel")
    callback("Cancel")
  end)
  review.start()
  local active = review._current()

  review._action("delete")

  MiniTest.expect.equality(delete_called, false)
  MiniTest.expect.equality(active.session:current().path, "6. Inbox/First.md")
  MiniTest.expect.equality(active.session:snapshot().processed, 0)
  MiniTest.expect.equality(active.view:is_valid(), true)
end

T["keeps the current note open when Obsidian trash fails"] = function()
  local root = vim.fn.tempname()
  create_notes(root, { "First" })
  cli._set_executor(executor(root, {
    delete_result = { code = 2, stdout = "", stderr = "Trash unavailable" },
  }))
  ui._set_select(function(_, _, callback)
    callback("Move to trash")
  end)
  local notifications = {}
  local old_notify = vim.notify
  vim.notify = function(message)
    table.insert(notifications, message)
  end
  review.start()
  local active = review._current()

  review._action("delete")
  vim.notify = old_notify

  MiniTest.expect.equality(active.session:current().path, "6. Inbox/First.md")
  MiniTest.expect.equality(active.session:snapshot().processed, 0)
  MiniTest.expect.equality(active.view:is_valid(), true)
  MiniTest.expect.equality(notifications, { "obsidian-para-flow: Trash unavailable" })
end

T["does not dispatch another action while trash is pending"] = function()
  local root = vim.fn.tempname()
  create_notes(root, { "First" })
  local delete_calls = 0
  local complete_delete
  cli._set_executor(executor(root, {
    defer_delete = true,
    on_delete = function(_, callback)
      delete_calls = delete_calls + 1
      complete_delete = callback
    end,
  }))
  ui._set_select(function(_, _, callback)
    callback("Move to trash")
  end)
  review.start()
  local active = review._current()

  review._action("delete")
  review._action("delete")
  review._action("quit")

  MiniTest.expect.equality(delete_calls, 1)
  MiniTest.expect.equality(active.pending_action, "delete")
  MiniTest.expect.equality(active.view:is_valid(), true)

  complete_delete({ code = 0, stdout = "", stderr = "" })

  MiniTest.expect.equality(active.pending_action, nil)
  MiniTest.expect.equality(active.session:snapshot().status, "finished")
  MiniTest.expect.equality(active.session:snapshot().actions, { delete = 1 })
end

T["cancels a saving action when the note changed outside Neovim"] = function()
  local root = vim.fn.tempname()
  create_notes(root, { "First", "Second" })
  cli._set_executor(executor(root, { files = "6. Inbox/First.md\n6. Inbox/Second.md" }))
  review.start()
  local active = review._current()
  vim.api.nvim_buf_set_lines(active.target.buffer, -1, -1, false, { "Local edit" })
  vim.fn.writefile(
    { "# First", "External replacement with a different size" },
    active.target.full_path
  )
  local notifications = {}
  local old_notify = vim.notify
  vim.notify = function(message)
    table.insert(notifications, message)
  end

  review._action("skip")
  vim.notify = old_notify

  MiniTest.expect.equality(active.session:current().path, "6. Inbox/First.md")
  MiniTest.expect.equality(vim.bo[active.target.buffer].modified, true)
  MiniTest.expect.equality(notifications, {
    "obsidian-para-flow: The current note changed outside Neovim; action canceled",
  })
end

T["keeps the current note open when Neovim cannot save it"] = function()
  local root = vim.fn.tempname()
  create_notes(root, { "First", "Second" })
  cli._set_executor(executor(root, { files = "6. Inbox/First.md\n6. Inbox/Second.md" }))
  review.start()
  local active = review._current()
  vim.api.nvim_buf_set_lines(active.target.buffer, -1, -1, false, { "Unsaved" })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = active.target.buffer,
    once = true,
    callback = function()
      error("simulated write failure")
    end,
  })
  local notifications = {}
  local old_notify = vim.notify
  vim.notify = function(message)
    table.insert(notifications, message)
  end

  review._action("skip")
  vim.notify = old_notify

  MiniTest.expect.equality(active.session:current().path, "6. Inbox/First.md")
  MiniTest.expect.equality(vim.bo[active.target.buffer].modified, true)
  MiniTest.expect.equality(notifications[1]:match("Could not save the current note") ~= nil, true)
end

T["saves perform-now and opens the note in the originating window"] = function()
  local origin = vim.api.nvim_get_current_win()
  local root = vim.fn.tempname()
  create_notes(root, { "First" })
  cli._set_executor(executor(root))
  review.start()
  local active = review._current()
  vim.api.nvim_buf_set_lines(active.target.buffer, -1, -1, false, { "Done now" })

  review._action("perform_now")

  MiniTest.expect.equality(active.session:snapshot().status, "paused")
  MiniTest.expect.equality(active.session:snapshot().pause_reason, "perform_now")
  MiniTest.expect.equality(active.view:is_valid(), false)
  MiniTest.expect.equality(vim.api.nvim_get_current_win(), origin)
  MiniTest.expect.equality(vim.api.nvim_win_get_buf(origin), active.target.buffer)
  MiniTest.expect.equality(vim.bo[active.target.buffer].modified, false)
  MiniTest.expect.equality(vim.fn.maparg("e", "n"), "")
  MiniTest.expect.equality(vim.fn.maparg("s", "n"), "")
  MiniTest.expect.equality(vim.fn.maparg("q", "n"), "")
end

T["keeps modified review open when quit is canceled"] = function()
  local root = vim.fn.tempname()
  create_notes(root, { "First" })
  cli._set_executor(executor(root))
  ui._set_select(function(items, options, callback)
    MiniTest.expect.equality(items, { "Cancel", "Save and exit", "Discard and exit" })
    MiniTest.expect.equality(options.prompt, "The current note has unsaved changes:")
    callback("Cancel")
  end)
  review.start()
  local active = review._current()
  vim.api.nvim_buf_set_lines(active.target.buffer, -1, -1, false, { "Keep editing" })

  review._action("quit")

  MiniTest.expect.equality(active.view:is_valid(), true)
  MiniTest.expect.equality(vim.bo[active.target.buffer].modified, true)
end

T["quits an unchanged review without prompting or changing the Inbox"] = function()
  local root = vim.fn.tempname()
  create_notes(root, { "First" })
  cli._set_executor(executor(root))
  ui._set_select(function()
    error("quit should not prompt for an unchanged buffer")
  end)
  review.start()
  local active = review._current()

  review._action("quit")

  MiniTest.expect.equality(review._current(), nil)
  MiniTest.expect.equality(active.view:is_valid(), false)
  MiniTest.expect.equality(vim.fn.readfile(root .. "/6. Inbox/First.md"), {
    "# First",
    "",
    "First body",
  })
end

T["can save or discard changes before quitting"] = function()
  for _, case in ipairs({
    { choice = "Save and exit", expected = { "# First", "", "First body", "Changed" } },
    { choice = "Discard and exit", expected = { "# First", "", "First body" } },
  }) do
    review._reset()
    local root = vim.fn.tempname()
    create_notes(root, { "First" })
    cli._set_executor(executor(root))
    ui._set_select(function(_, _, callback)
      callback(case.choice)
    end)
    review.start()
    local active = review._current()
    vim.api.nvim_buf_set_lines(active.target.buffer, -1, -1, false, { "Changed" })

    review._action("quit")

    MiniTest.expect.equality(review._current(), nil)
    MiniTest.expect.equality(active.view:is_valid(), false)
    vim.api.nvim_buf_call(active.target.buffer, function()
      MiniTest.expect.equality(vim.fn.maparg("d", "n"), "")
      MiniTest.expect.equality(vim.fn.maparg("e", "n"), "")
      MiniTest.expect.equality(vim.fn.maparg("s", "n"), "")
      MiniTest.expect.equality(vim.fn.maparg("q", "n"), "")
    end)
    MiniTest.expect.equality(vim.fn.readfile(root .. "/6. Inbox/First.md"), case.expected)
  end
end

T["finishes a skipped pass without claiming that Inbox is empty"] = function()
  local root = vim.fn.tempname()
  create_notes(root, { "First" })
  cli._set_executor(executor(root))
  local notifications = {}
  local old_notify = vim.notify
  vim.notify = function(message)
    table.insert(notifications, message)
  end
  review.start()
  local active = review._current()

  review._action("skip")
  vim.notify = old_notify

  MiniTest.expect.equality(active.view:is_valid(), false)
  MiniTest.expect.equality(notifications, {
    "obsidian-para-flow: Review finished: 0 processed, 1 skipped, 1 remaining in Inbox",
  })
end

T["sorts into PARA only after preflight and advances after the final move"] = function()
  local root = vim.fn.tempname()
  create_notes(root, { "First" })
  local commands = {}
  cli._set_executor(function(argv, _, callback)
    local command = argv[2]
    table.insert(commands, command)
    if command == "files" then
      local is_inbox = argv[3] == "folder=6. Inbox"
      callback({ code = 0, stdout = is_inbox and "6. Inbox/First.md" or "", stderr = "" })
    elseif command == "properties" then
      callback({
        code = 0,
        stdout = '{"created":"2026-07-20","area":"[[2. Areas/Work]]"}',
        stderr = "",
      })
    elseif command == "file" then
      callback({ code = 0, stdout = "path 6. Inbox/First.md\ncreated 1000", stderr = "" })
    elseif command == "vault" then
      callback({ code = 0, stdout = root, stderr = "" })
    elseif command == "folders" then
      callback({ code = 0, stdout = "1. Projects/Child", stderr = "" })
    elseif command == "folder" or command == "property:set" or command == "move" then
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end)
  ui._set_select(function(items, _, callback)
    callback(items[1])
  end)
  review.start()
  local active = review._current()

  review._action("projects")

  MiniTest.expect.equality(active.session:snapshot().status, "finished")
  MiniTest.expect.equality(active.session:snapshot().actions, { projects = 1 })
  MiniTest.expect.equality(active.view:is_valid(), false)
  local move_index
  for index, command in ipairs(commands) do
    if command == "move" then
      move_index = index
    end
  end
  MiniTest.expect.equality(move_index, #commands)
end

T["does not save a modified note when the folder picker is canceled"] = function()
  local root = vim.fn.tempname()
  create_notes(root, { "First" })
  cli._set_executor(executor(root))
  ui._set_select(function(_, _, callback)
    callback(nil)
  end)
  review.start()
  local active = review._current()
  vim.api.nvim_buf_set_lines(active.target.buffer, -1, -1, false, { "Unsaved" })

  review._action("projects")

  MiniTest.expect.equality(vim.bo[active.target.buffer].modified, true)
  MiniTest.expect.equality(vim.fn.readfile(root .. "/6. Inbox/First.md"), {
    "# First",
    "",
    "First body",
  })
  MiniTest.expect.equality(active.session:snapshot().processed, 0)
end

T["halts review with recovery details after an incomplete rollback"] = function()
  local root = vim.fn.tempname()
  create_notes(root, { "First" })
  cli._set_executor(function(argv, _, callback)
    local command = argv[2]
    if command == "files" then
      callback({
        code = 0,
        stdout = argv[3] == "folder=6. Inbox" and "6. Inbox/First.md" or "",
        stderr = "",
      })
    elseif command == "properties" then
      callback({
        code = 0,
        stdout = '{"created":"2026-07-20","area":"[[2. Areas/Work]]"}',
        stderr = "",
      })
    elseif command == "file" then
      callback({ code = 0, stdout = "created 1000", stderr = "" })
    elseif command == "vault" then
      callback({ code = 0, stdout = root, stderr = "" })
    elseif command == "folders" or command == "folder" or command == "property:set" then
      callback({ code = 0, stdout = "", stderr = "" })
    elseif command == "move" then
      callback({ code = 2, stdout = "", stderr = "move failed" })
    elseif command == "property:remove" then
      callback({ code = 2, stdout = "", stderr = "rollback failed" })
    end
  end)
  ui._set_select(function(items, _, callback)
    callback(items[1])
  end)
  local notifications = {}
  local old_notify = vim.notify
  vim.notify = function(message)
    table.insert(notifications, message)
  end
  review.start()
  local active = review._current()

  review._action("projects")
  vim.notify = old_notify

  local snapshot = active.session:snapshot()
  MiniTest.expect.equality(snapshot.status, "halted")
  MiniTest.expect.equality(snapshot.processed, 0)
  MiniTest.expect.equality(snapshot.emergency.details.source, "6. Inbox/First.md")
  MiniTest.expect.equality(#snapshot.emergency.details.rollback_failures > 0, true)
  MiniTest.expect.equality(notifications[1]:match("rollback failed") ~= nil, true)
end

T["reports Inbox loading failures without opening review"] = function()
  local notifications = {}
  local old_notify = vim.notify
  vim.notify = function(message)
    table.insert(notifications, message)
  end
  cli._set_executor(function(_, _, callback)
    callback({ code = 2, stdout = "", stderr = "Could not list Inbox" })
  end)

  review.start()
  vim.notify = old_notify

  MiniTest.expect.equality(review._current(), nil)
  MiniTest.expect.equality(notifications, { "obsidian-para-flow: Could not list Inbox" })
end

T["reports an empty Inbox without creating a review layout"] = function()
  local notifications = {}
  local old_notify = vim.notify
  vim.notify = function(message)
    table.insert(notifications, message)
  end
  cli._set_executor(executor("/unused", { files = "" }))

  review.start()
  vim.notify = old_notify

  MiniTest.expect.equality(review._current(), nil)
  MiniTest.expect.equality(notifications, { "obsidian-para-flow: Inbox is empty" })
end

return T
