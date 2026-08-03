local menu = require("obsidian-para-flow.metadata_menu")

local T = MiniTest.new_set({
  hooks = {
    post_case = function()
      package.loaded["obsidian-para-flow.date_property"] = nil
      package.loaded["obsidian-para-flow.add_property"] = nil
      pcall(vim.cmd, "silent! only")
    end,
  },
})

T["opens an extensible metadata menu and dispatches the date action"] = function()
  local started = 0
  package.loaded["obsidian-para-flow.date_property"] = {
    start = function()
      started = started + 1
    end,
  }
  local added = 0
  package.loaded["obsidian-para-flow.add_property"] = {
    start = function()
      added = added + 1
    end,
  }

  local view = menu.start()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(view.buffer, 0, -1, false), {
    "[d] Date property",
    "[a] Add property",
  })
  MiniTest.expect.equality(vim.api.nvim_win_get_config(view.window).title, {
    { " Metadata ", "ObsidianParaReviewTitle" },
  })
  vim.fn.maparg("d", "n", false, true).callback()
  MiniTest.expect.equality(started, 1)

  view = menu.start()
  vim.fn.maparg("a", "n", false, true).callback()
  MiniTest.expect.equality(added, 1)
end

return T
