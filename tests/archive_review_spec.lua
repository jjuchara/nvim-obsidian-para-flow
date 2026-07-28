local config = require("obsidian-para-flow.config")
local helpers = require("tests.helpers.config")
local ui = require("obsidian-para-flow.ui")

local original_action_list = ui.action_list
local original_loader = package.loaded["obsidian-para-flow.archive_loader"]

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

return T
