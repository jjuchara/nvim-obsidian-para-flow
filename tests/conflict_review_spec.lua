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

local function create_vault()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/6. Inbox", "p")
  vim.fn.mkdir(root .. "/1. Projects", "p")
  vim.fn.writefile({ "# Note", "", "Inbox body" }, root .. "/6. Inbox/Note.md")
  vim.fn.writefile({ "# Note", "", "Target body" }, root .. "/1. Projects/Note.md")
  return root
end

local function executor(root, options)
  options = options or {}
  local writes = 0
  return function(argv, _, callback)
    local command = argv[2]
    local argument = argv[3] or ""
    if options.calls then
      table.insert(options.calls, argv)
    end
    if command == "files" then
      local output
      if argument == "folder=6. Inbox" then
        output = "6. Inbox/Note.md"
      else
        output = options.project_files or "1. Projects/Note.md"
      end
      callback({ code = 0, stdout = output, stderr = "" })
    elseif command == "properties" then
      if argument == "path=1. Projects/Note.md" then
        callback({ code = 0, stdout = '{"status":"Active","tags":["target"]}', stderr = "" })
      else
        callback({
          code = 0,
          stdout = '{"created":"2026-07-20","area":"[[2. Areas/Work]]","tags":["source"]}',
          stderr = "",
        })
      end
    elseif command == "file" then
      callback({ code = 0, stdout = "path 6. Inbox/Note.md\ncreated 1000", stderr = "" })
    elseif command == "vault" then
      callback({ code = 0, stdout = root, stderr = "" })
    elseif
      command == "folders"
      or command == "folder"
      or command == "property:set"
      or command == "move"
    then
      callback({ code = 0, stdout = "", stderr = "" })
    elseif command == "read" then
      if argument == "path=1. Projects/Note.md" then
        callback({ code = 0, stdout = "# Note\n\nTarget body\n", stderr = "" })
      else
        callback({ code = 0, stdout = "# Note\n\nInbox body\n", stderr = "" })
      end
    elseif command == "create" then
      writes = writes + 1
      if options.fail_restore and writes > 1 then
        callback({ code = 2, stdout = "", stderr = "restore failed" })
      else
        callback({ code = 0, stdout = "", stderr = "" })
      end
    elseif command == "delete" then
      callback(
        options.fail_delete and { code = 2, stdout = "", stderr = "trash failed" }
          or { code = 0, stdout = "", stderr = "" }
      )
    else
      error("unexpected command: " .. tostring(command))
    end
  end
end

local function enter_conflict(root, options)
  cli._set_executor(executor(root, options))
  ui._set_select(function(items, _, callback)
    callback(items[1])
  end)
  review.start()
  review._action("projects")
  return review._current()
end

T["opens labeled read-only panes, switches focus, and returns unchanged"] = function()
  local root = create_vault()
  local active = enter_conflict(root)

  MiniTest.expect.equality(active.conflict.prepared.destination, "1. Projects/Note.md")
  MiniTest.expect.equality(active.view.mode, "compare")
  MiniTest.expect.equality(vim.bo[active.target.buffer].readonly, true)
  MiniTest.expect.equality(vim.bo[active.conflict.target_buffer].readonly, true)
  MiniTest.expect.equality(vim.api.nvim_get_current_win(), active.view.windows.compare_inbox)

  review._action("conflict_focus")
  MiniTest.expect.equality(vim.api.nvim_get_current_win(), active.view.windows.body)
  review._action("conflict_quit")

  MiniTest.expect.equality(active.conflict, nil)
  MiniTest.expect.equality(active.view.mode, nil)
  MiniTest.expect.equality(vim.bo[active.target.buffer].modifiable, true)
  MiniTest.expect.equality(active.session:snapshot().processed, 0)
end

T["keeps the resolver open when rename finds another exact conflict"] = function()
  local root = create_vault()
  vim.fn.writefile({ "# Renamed" }, root .. "/1. Projects/Renamed.md")
  local active = enter_conflict(root, {
    project_files = "1. Projects/Note.md\n1. Projects/Renamed.md",
  })
  ui._set_input(function(_, callback)
    callback("Renamed.md")
  end)

  review._action("conflict_rename")

  MiniTest.expect.equality(active.conflict.prepared.destination, "1. Projects/Renamed.md")
  MiniTest.expect.equality(active.view.mode, "compare")
  MiniTest.expect.equality(active.session:snapshot().processed, 0)
end

T["deletes the Inbox source through the common safe confirmation"] = function()
  local root = create_vault()
  local calls = {}
  local active = enter_conflict(root, { calls = calls })
  ui._set_select(function(items, options, callback)
    MiniTest.expect.equality(items, { "Cancel", "Move to trash" })
    MiniTest.expect.equality(options.prompt, "Move `6. Inbox/Note.md` to the Obsidian trash?")
    callback("Move to trash")
  end)

  review._action("conflict_delete")

  local deletes = 0
  for _, argv in ipairs(calls) do
    if argv[2] == "delete" then
      deletes = deletes + 1
    end
  end
  MiniTest.expect.equality(deletes, 1)
  MiniTest.expect.equality(active.session:snapshot().actions, { delete = 1 })
end

T["renames only as part of the final PARA move"] = function()
  local root = create_vault()
  local calls = {}
  local active = enter_conflict(root, { calls = calls })
  ui._set_input(function(_, callback)
    callback("Renamed")
  end)
  cli._set_executor(function(argv, timeout, callback)
    if argv[2] == "files" and argv[3] == "folder=1. Projects" then
      callback({ code = 0, stdout = "", stderr = "" })
      return
    end
    executor(root, { calls = calls })(argv, timeout, callback)
  end)

  review._action("conflict_rename")

  local move
  local rename_called = false
  for _, argv in ipairs(calls) do
    if argv[2] == "move" then
      move = argv
    elseif argv[2] == "rename" then
      rename_called = true
    end
  end
  MiniTest.expect.equality(rename_called, false)
  MiniTest.expect.equality(move[4], "to=1. Projects/Renamed.md")
  MiniTest.expect.equality(active.session:snapshot().actions, { projects = 1 })
end

T["builds an editable preview and commits write before trash"] = function()
  local root = create_vault()
  local calls = {}
  local active = enter_conflict(root, { calls = calls })

  review._action("conflict_merge")
  local preview = active.conflict.preview
  MiniTest.expect.equality(active.view.mode, "preview")
  MiniTest.expect.equality(vim.bo[preview.buffer].modifiable, true)
  MiniTest.expect.equality(
    table
      .concat(vim.api.nvim_buf_get_lines(preview.buffer, 0, -1, false), "\n")
      :find("Target body\n\n---\n\nInbox body", 1, true) ~= nil,
    true
  )
  vim.fn.maparg("<leader>om", "n", false, true).callback()

  local mutations = {}
  for _, argv in ipairs(calls) do
    if argv[2] == "create" or argv[2] == "delete" then
      table.insert(mutations, argv[2])
    end
  end
  MiniTest.expect.equality(mutations, { "create", "delete" })
  MiniTest.expect.equality(active.session:snapshot().actions, { merge = 1 })
  MiniTest.expect.equality(active.session:snapshot().status, "finished")
end

T["keeps an edited preview open when safe cancellation is selected"] = function()
  local root = create_vault()
  local active = enter_conflict(root)
  review._action("conflict_merge")
  local preview = active.conflict.preview
  vim.api.nvim_buf_set_lines(preview.buffer, -1, -1, false, { "Manual edit" })
  vim.bo[preview.buffer].modified = true
  ui._set_select(function(items, _, callback)
    MiniTest.expect.equality(items, { "Cancel", "Discard preview" })
    callback("Cancel")
  end)

  MiniTest.expect.equality(vim.bo[preview.buffer].modified, true)
  vim.fn.maparg("<leader>oq", "n", false, true).callback()

  MiniTest.expect.equality(active.view.mode, "preview")
  MiniTest.expect.equality(vim.api.nvim_buf_is_valid(preview.buffer), true)
  MiniTest.expect.equality(vim.bo[preview.buffer].modified, true)
end

T["halts review when a failed merge cannot restore the target"] = function()
  local root = create_vault()
  local active = enter_conflict(root, { fail_delete = true, fail_restore = true })
  local notifications = {}
  local old_notify = vim.notify
  vim.notify = function(message)
    table.insert(notifications, message)
  end

  review._action("conflict_merge")
  vim.fn.maparg("<leader>om", "n", false, true).callback()
  vim.notify = old_notify

  local snapshot = active.session:snapshot()
  MiniTest.expect.equality(snapshot.status, "halted")
  MiniTest.expect.equality(snapshot.emergency.details.target, "1. Projects/Note.md")
  MiniTest.expect.equality(snapshot.emergency.details.source, "6. Inbox/Note.md")
  MiniTest.expect.equality(notifications[1]:find("restore failed", 1, true) ~= nil, true)
end

return T
