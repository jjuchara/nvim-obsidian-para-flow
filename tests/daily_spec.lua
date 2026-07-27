local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local daily = require("obsidian-para-flow.daily")
local helpers = require("tests.helpers.config")
local ui = require("obsidian-para-flow.ui")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      cli._reset()
      config._reset()
      config.setup(helpers.valid())
    end,
    post_case = function()
      ui._reset()
      cli._reset()
      config._reset()
    end,
  },
})

T["accepts short actions and every official Daily notes alias"] = function()
  MiniTest.expect.equality(daily._aliases(), {
    ["daily"] = "open",
    ["daily:path"] = "path",
    ["daily:read"] = "read",
    ["daily:append"] = "append",
    ["daily:prepend"] = "prepend",
    today = "open",
    open = "open",
    path = "path",
    read = "read",
    append = "append",
    prepend = "prepend",
  })
end

T["opens today's generated path in a new Neovim tab"] = function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(vim.fs.joinpath(root, "5. Daily"), "p")
  local path = "5. Daily/27.07.2026.md"
  local file = assert(io.open(vim.fs.joinpath(root, path), "w"))
  file:write("# Daily\n")
  file:close()

  local commands = {}
  cli._set_executor(function(argv, _, callback)
    table.insert(commands, argv[2])
    local stdout = argv[2] == "daily:path" and path
      or (argv[2] == "vault" and (argv[3] == "info=name" and "Test Vault" or root) or "")
    callback({ code = 0, signal = 0, stdout = stdout, stderr = "" })
  end)

  local origin = vim.api.nvim_get_current_tabpage()
  daily.run("today")
  MiniTest.expect.no_equality(vim.api.nvim_get_current_tabpage(), origin)
  MiniTest.expect.equality(
    vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0)),
    vim.uv.fs_realpath(vim.fs.joinpath(root, path))
  )
  MiniTest.expect.equality(commands, { "vault", "daily:path", "daily", "vault" })
  vim.cmd("tabclose")
end

T["shows daily:path without opening a tab"] = function()
  cli._set_executor(function(argv, _, callback)
    local stdout = argv[2] == "vault" and "Test Vault" or "5. Daily/27.07.2026.md"
    callback({ code = 0, signal = 0, stdout = stdout, stderr = "" })
  end)
  local previous_notify = vim.notify
  local notification
  vim.notify = function(message)
    notification = message
  end

  local origin = vim.api.nvim_get_current_tabpage()
  daily.run("daily:path")
  vim.notify = previous_notify
  MiniTest.expect.equality(vim.api.nvim_get_current_tabpage(), origin)
  MiniTest.expect.equality(notification, "5. Daily/27.07.2026.md")
end

T["reads into a read-only Markdown scratch"] = function()
  cli._set_executor(function(argv, _, callback)
    local stdout = argv[2] == "vault" and "Test Vault" or "# Today\n\nBody"
    callback({ code = 0, signal = 0, stdout = stdout, stderr = "" })
  end)

  local origin = vim.api.nvim_get_current_tabpage()
  daily.run("daily:read")
  MiniTest.expect.no_equality(vim.api.nvim_get_current_tabpage(), origin)
  MiniTest.expect.equality(vim.bo.filetype, "markdown")
  MiniTest.expect.equality(vim.bo.modifiable, false)
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "# Today", "", "Body" })
  vim.cmd("tabclose")
end

T["prompts for missing append content and cancels without CLI mutation"] = function()
  local mutations = 0
  cli._set_executor(function(argv, _, callback)
    if argv[2] ~= "vault" then
      mutations = mutations + 1
    end
    callback({ code = 0, signal = 0, stdout = "Test Vault", stderr = "" })
  end)
  ui._set_input(function(_, callback)
    callback(nil)
  end)

  daily.run("append")
  MiniTest.expect.equality(mutations, 0)
end

T["passes explicit append and prompted prepend content"] = function()
  local commands = {}
  cli._set_executor(function(argv, _, callback)
    if argv[2] ~= "vault" then
      table.insert(commands, { argv[2], argv[3] })
    end
    callback({ code = 0, signal = 0, stdout = "Test Vault", stderr = "" })
  end)
  ui._set_input(function(_, callback)
    callback("first line")
  end)

  daily.run("daily:append", "last line")
  daily.run("prepend")
  MiniTest.expect.equality(commands, {
    { "daily:append", "content=last line" },
    { "daily:prepend", "content=first line" },
  })
end

T["stops before a Daily action when the CLI resolves another vault"] = function()
  local commands = {}
  cli._set_executor(function(argv, _, callback)
    table.insert(commands, argv[2])
    callback({ code = 0, signal = 0, stdout = "Production Vault", stderr = "" })
  end)

  daily.run("daily:append", "do not write")
  MiniTest.expect.equality(commands, { "vault" })
end

return T
