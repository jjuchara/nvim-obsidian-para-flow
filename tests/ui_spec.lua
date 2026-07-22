local ui = require("obsidian-para-flow.ui")

local T = MiniTest.new_set({
  hooks = {
    post_case = function()
      ui._reset()
    end,
  },
})

T["opens a centered float with common status body and footer regions"] = function()
  local origin = vim.api.nvim_get_current_win()
  local view = ui.open_review({
    layout = "float",
    width = 40,
    height = 10,
    winblend = 10,
    title = "Review queue",
    status = { "Inbox review · 1/3" },
    footer = { "p Projects · q Quit" },
  })

  MiniTest.expect.equality(view.layout, "float")
  MiniTest.expect.equality(vim.api.nvim_get_current_win(), view.windows.body)
  MiniTest.expect.equality(vim.api.nvim_win_get_config(view.windows.frame).width, 40)
  MiniTest.expect.equality(vim.api.nvim_win_get_config(view.windows.frame).height, 10)
  MiniTest.expect.equality(vim.api.nvim_win_get_config(view.windows.frame).title, {
    { " Review queue ", "ObsidianParaReviewTitle" },
  })
  MiniTest.expect.equality(vim.api.nvim_win_get_config(view.windows.body).width, 36)
  MiniTest.expect.equality(vim.api.nvim_win_get_height(view.windows.status), 1)
  MiniTest.expect.equality(vim.api.nvim_win_get_height(view.windows.body), 8)
  MiniTest.expect.equality(vim.api.nvim_win_get_height(view.windows.footer), 1)
  MiniTest.expect.equality(vim.wo[view.windows.body].winblend, 10)
  MiniTest.expect.equality(
    vim.wo[view.windows.body].winhighlight:find("Normal:ObsidianParaReviewNormal", 1, true) ~= nil,
    true
  )
  local surface = vim.api.nvim_get_hl(0, { name = "ObsidianParaReviewNormal" })
  local popup = vim.api.nvim_get_hl(0, { name = "Pmenu", link = false })
  MiniTest.expect.no_equality(surface.bg, nil)
  if popup.bg then
    MiniTest.expect.equality(surface.bg, popup.bg)
  end
  MiniTest.expect.equality(
    vim.wo[view.windows.footer].winhighlight:find("Normal:ObsidianParaReviewChrome", 1, true) ~= nil,
    true
  )
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(view.buffers.status, 0, -1, false),
    { "Inbox review · 1/3" }
  )

  view:close()
  MiniTest.expect.equality(vim.api.nvim_get_current_win(), origin)
  MiniTest.expect.equality(view:is_valid(), false)
end

T["resolves fractional float dimensions against the editor"] = function()
  local view = ui.open_review({ layout = "float", width = 0.5, height = 0.5 })
  local config = vim.api.nvim_win_get_config(view.windows.frame)

  MiniTest.expect.equality(config.width, math.floor((vim.o.columns - 2) * 0.5))
  MiniTest.expect.equality(
    config.height,
    math.max(3, math.floor((vim.o.lines - vim.o.cmdheight - 2) * 0.5))
  )
  view:close()
end

T["opens fullscreen in a dedicated tab and restores the origin"] = function()
  local origin_window = vim.api.nvim_get_current_win()
  local origin_tabs = #vim.api.nvim_list_tabpages()
  local view = ui.open_review({
    layout = "fullscreen",
    status = { "Inbox review" },
    footer = { "q Quit" },
  })

  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), origin_tabs + 1)
  MiniTest.expect.equality(vim.api.nvim_get_current_win(), view.windows.body)
  MiniTest.expect.equality(vim.api.nvim_win_get_height(view.windows.status), 1)
  MiniTest.expect.equality(vim.api.nvim_win_get_height(view.windows.footer), 1)

  view:close()
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), origin_tabs)
  MiniTest.expect.equality(vim.api.nvim_get_current_win(), origin_window)
end

T["renders updated chrome without changing the body buffer"] = function()
  local body = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(body, 0, -1, false, { "# Note", "Body" })
  local view = ui.open_review({ layout = "float", body_buffer = body })

  view:render({ status = { "2/4" }, footer = { "s Skip" } })

  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(body, 0, -1, false), { "# Note", "Body" })
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(view.buffers.status, 0, -1, false), { "2/4" })
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(view.buffers.footer, 0, -1, false),
    { "s Skip" }
  )

  view:close()
  MiniTest.expect.equality(vim.api.nvim_buf_is_valid(body), true)
  vim.api.nvim_buf_delete(body, { force = true })
end

T["switches between read-only conflict comparison and editable merge preview"] = function()
  local inbox = vim.api.nvim_create_buf(false, true)
  local target = vim.api.nvim_create_buf(false, true)
  local preview = vim.api.nvim_create_buf(false, true)
  local view = ui.open_review({ layout = "float", width = 50, height = 12, body_buffer = inbox })

  view:show_compare(target, inbox, {
    status = { "Destination conflict" },
    footer = { "m Merge · <Tab> Focus" },
  })

  MiniTest.expect.equality(view.mode, "compare")
  MiniTest.expect.equality(vim.bo[target].readonly, true)
  MiniTest.expect.equality(vim.bo[inbox].modifiable, false)
  MiniTest.expect.equality(vim.api.nvim_win_is_valid(view.windows.compare_inbox), true)
  MiniTest.expect.equality(vim.wo[view.windows.compare_inbox].winblend, view.winblend)
  MiniTest.expect.equality(
    vim.wo[view.windows.compare_inbox].winhighlight:find("Normal:ObsidianParaReviewNormal", 1, true)
      ~= nil,
    true
  )

  view:show_preview(preview, {
    status = { "Merge Preview" },
    footer = { "<leader>om Apply merge" },
  })
  MiniTest.expect.equality(view.mode, "preview")
  MiniTest.expect.equality(vim.api.nvim_win_get_buf(view.windows.body), preview)
  MiniTest.expect.equality(view.windows.compare_inbox, nil)

  view:show_compare_again({ status = { "Destination conflict" }, footer = { "q Back" } })
  MiniTest.expect.equality(view.mode, "compare")
  MiniTest.expect.equality(vim.api.nvim_win_is_valid(view.windows.compare_inbox), true)

  view:restore_review(inbox, { status = { "Inbox review" }, footer = { "q Quit" } })
  MiniTest.expect.equality(view.mode, nil)
  MiniTest.expect.equality(vim.bo[inbox].modifiable, true)
  MiniTest.expect.equality(vim.bo[inbox].readonly, false)
  MiniTest.expect.equality(vim.api.nvim_win_get_buf(view.windows.body), inbox)
  view:close()
end

T["rejects unsupported layouts"] = function()
  MiniTest.expect.error(function()
    ui.open_review({ layout = "split" })
  end)
end

T["delegates prompts through the active vim.ui provider"] = function()
  local previous_input = vim.ui.input
  local previous_select = vim.ui.select
  local calls = {}
  vim.ui.input = function(options, callback)
    calls.input = options.prompt
    callback("typed")
  end
  vim.ui.select = function(items, options, callback)
    calls.select = { items = items, prompt = options.prompt }
    callback(items[2], 2)
  end

  local input_value
  local selected_value
  ui.input({ prompt = "Archive reason: " }, function(value)
    input_value = value
  end)
  ui.select({ "root", "nested" }, { prompt = "Destination:" }, function(value)
    selected_value = value
  end)
  vim.ui.input = previous_input
  vim.ui.select = previous_select

  MiniTest.expect.equality(calls.input, "Archive reason: ")
  MiniTest.expect.equality(calls.select, {
    items = { "root", "nested" },
    prompt = "Destination:",
  })
  MiniTest.expect.equality(input_value, "typed")
  MiniTest.expect.equality(selected_value, "nested")
end

return T
