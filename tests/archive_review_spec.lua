local config = require("obsidian-para-flow.config")
local helpers = require("tests.helpers.config")
local ui = require("obsidian-para-flow.ui")

local original_keyed_select = ui.keyed_select
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
      ui.keyed_select = original_keyed_select
      package.loaded["obsidian-para-flow.archive_loader"] = original_loader
      package.loaded["obsidian-para-flow.archive_review"] = nil
      ui._reset()
      config._reset()
    end,
  },
})

T["advertises queue controls and opens the visible keyed action menu"] = function()
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

  local queue_prompt
  local action_menu
  ui._set_select(function(items, options, callback)
    queue_prompt = options.prompt
    callback(items[1])
  end)
  ui.keyed_select = function(items, options)
    action_menu = { items = items, prompt = options.prompt }
  end

  require("obsidian-para-flow.archive_review").start()

  MiniTest.expect.equality(queue_prompt, "Expired notes (1) · <CR> actions · <Esc> close:")
  MiniTest.expect.equality(action_menu.prompt, note.path)
  MiniTest.expect.equality(action_menu.items, {
    { key = "r", label = "Reschedule expiration", value = "reschedule" },
    { key = "a", label = "Archive", value = "archive" },
    { key = "d", label = "Move to trash", value = "trash" },
    { key = "s", label = "Skip", value = "skip" },
    { key = "q", label = "Back", value = "back" },
  })
end

return T
