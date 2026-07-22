local helpers = require("tests.helpers.config")
local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local review = require("obsidian-para-flow.review")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      review._reset()
      cli._reset()
      config._reset()
      config.setup(helpers.valid())
    end,
    post_case = function()
      review._reset()
      cli._reset()
    end,
  },
})

local function executor(root, options)
  options = options or {}
  return function(argv, _, callback)
    local command = argv[3]
    if command == "files" then
      callback({ code = 0, stdout = options.files or "6. Inbox/First.md", stderr = "" })
    elseif command == "properties" then
      callback({ code = 0, stdout = '{"created":"2026-07-20"}', stderr = "" })
    elseif command == "file" then
      callback({ code = 0, stdout = "created 1000", stderr = "" })
    elseif command == "vault" then
      callback({ code = 0, stdout = options.vault_path or root, stderr = "" })
    end
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
  MiniTest.expect.equality(
    vim.api.nvim_buf_get_lines(active.view.buffers.status, 0, -1, false),
    { "Inbox review · 1/1 · 6. Inbox/First.md" }
  )
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(active.view.buffers.footer, 0, -1, false), {
    "p Project · a Area · r Resource · x Archive · d Delete · e Do now · s Skip · q Quit",
  })
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
