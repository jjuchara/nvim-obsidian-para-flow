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
    status = { "Inbox review · 1/3" },
    footer = { "p Projects · q Quit" },
  })

  MiniTest.expect.equality(view.layout, "float")
  MiniTest.expect.equality(vim.api.nvim_get_current_win(), view.windows.body)
  MiniTest.expect.equality(vim.api.nvim_win_get_config(view.windows.frame).width, 40)
  MiniTest.expect.equality(vim.api.nvim_win_get_config(view.windows.frame).height, 10)
  MiniTest.expect.equality(vim.api.nvim_win_get_height(view.windows.status), 1)
  MiniTest.expect.equality(vim.api.nvim_win_get_height(view.windows.body), 8)
  MiniTest.expect.equality(vim.api.nvim_win_get_height(view.windows.footer), 1)
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

T["rejects unsupported layouts"] = function()
  MiniTest.expect.error(function()
    ui.open_review({ layout = "split" })
  end)
end

return T
