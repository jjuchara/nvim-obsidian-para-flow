local config = require("obsidian-para-flow.config")
local helpers = require("tests.helpers.config")
local ui = require("obsidian-para-flow.ui")

local original_action_list = ui.action_list
local original_loader = package.loaded["obsidian-para-flow.archive_loader"]
local original_date_picker = package.loaded["obsidian-para-flow.date_picker"]
local original_cli = package.loaded["obsidian-para-flow.cli"]

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      config._reset()
      config.setup(helpers.valid())
      ui._reset()
    end,
    post_case = function()
      local review = package.loaded["obsidian-para-flow.archive_review"]
      if review then
        review._reset()
      end
      ui.action_list = original_action_list
      package.loaded["obsidian-para-flow.archive_loader"] = original_loader
      package.loaded["obsidian-para-flow.date_picker"] = original_date_picker
      package.loaded["obsidian-para-flow.cli"] = original_cli
      package.loaded["obsidian-para-flow.archive_review"] = nil
      ui._reset()
      config._reset()
    end,
  },
})

T["exposes selected-note actions directly on the queue"] = function()
  local note = {
    path = "3. Resources/Plan.md",
    expiration_property = "expired_at",
    expires = os.time({ year = 2026, month = 7, day = 27, hour = 0 }),
  }
  package.loaded["obsidian-para-flow.archive_loader"] = {
    load = function(_, callback)
      callback({ ok = true, invalid = {}, data = { note } })
    end,
  }

  local queue
  ui.action_list = function(items, options, callback)
    queue = { items = items, options = options, callback = callback }
  end

  require("obsidian-para-flow.archive_review").start()

  MiniTest.expect.equality(queue.items, { note })
  MiniTest.expect.equality(queue.options.title, "Expired notes (1)")
  MiniTest.expect.equality(
    queue.options.footer,
    "[r] Reschedule  [a] Archive  [d] Trash  [s] Skip  [q] Close"
  )
  MiniTest.expect.equality(queue.options.vertical_padding, 1)
  MiniTest.expect.equality(queue.options.actions, {
    { key = "r", value = "reschedule" },
    { key = "a", value = "archive" },
    { key = "d", value = "trash" },
    { key = "s", value = "skip" },
  })

  queue.callback("skip", note)
  vim.wait(100, function()
    return require("obsidian-para-flow.archive_review")._current() == nil
  end)
  MiniTest.expect.equality(require("obsidian-para-flow.archive_review")._current(), nil)
end

T["opens the configured calendar and keeps cancellation mutation-free"] = function()
  local note = {
    path = "3. Resources/Plan.md",
    expiration_property = "expired_at",
    expires = os.time({ year = 2026, month = 7, day = 27, hour = 0 }),
  }
  package.loaded["obsidian-para-flow.archive_loader"] = {
    load = function(_, callback)
      callback({ ok = true, invalid = {}, data = { note } })
    end,
  }
  local picker_options
  package.loaded["obsidian-para-flow.date_picker"] = {
    pick = function(options, callback)
      picker_options = options
      callback({ action = "cancel" })
    end,
  }

  local queues = {}
  ui.action_list = function(items, options, callback)
    queues[#queues + 1] = { items = items, options = options, callback = callback }
  end

  require("obsidian-para-flow.archive_review").start()
  queues[1].callback("reschedule", note)
  vim.wait(100, function()
    return #queues == 2
  end)

  MiniTest.expect.equality(picker_options.picker, "calendar")
  MiniTest.expect.equality(picker_options.title, "New expired_at")
  MiniTest.expect.equality(#queues, 2)
  MiniTest.expect.equality(queues[2].items, { note })
end

T["persists a selected calendar date after metadata revalidation"] = function()
  local note = {
    path = "1. Projects/Plan.md",
    expiration_property = "deadline",
    expires = os.time({ year = 2026, month = 7, day = 27, hour = 0 }),
    properties = { deadline = "2026-07-27" },
  }
  package.loaded["obsidian-para-flow.archive_loader"] = {
    load = function(_, callback)
      callback({ ok = true, invalid = {}, data = { note } })
    end,
  }
  package.loaded["obsidian-para-flow.date_picker"] = {
    pick = function(_, callback)
      callback({ action = "select", value = "2099-01-02" })
    end,
  }
  local mutation
  package.loaded["obsidian-para-flow.cli"] = {
    properties = function(vault, path, callback)
      MiniTest.expect.equality({ vault, path }, { "Test Vault", note.path })
      callback({ ok = true, data = vim.deepcopy(note.properties) })
    end,
    property_set = function(vault, path, property, value, value_type, callback)
      mutation = { vault, path, property, value, value_type }
      callback({ ok = true })
    end,
  }

  local queue
  ui.action_list = function(_, _, callback)
    queue = callback
  end

  require("obsidian-para-flow.archive_review").start()
  queue("reschedule", note)
  vim.wait(100, function()
    return require("obsidian-para-flow.archive_review")._current() == nil
  end)

  MiniTest.expect.equality(mutation, {
    "Test Vault",
    note.path,
    "deadline",
    "2099-01-02",
    "date",
  })
end

return T
