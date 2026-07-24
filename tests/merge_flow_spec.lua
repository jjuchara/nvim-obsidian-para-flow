local helpers = require("tests.helpers.config")
local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local merge_flow = require("obsidian-para-flow.merge_flow")
local ui = require("obsidian-para-flow.ui")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      merge_flow._reset()
      cli._reset()
      config._reset()
      ui._reset()
    end,
    post_case = function()
      merge_flow._reset()
      cli._reset()
      ui._reset()
    end,
  },
})

local function press(lhs)
  local mapping = vim.fn.maparg(lhs, "n", false, true)
  MiniTest.expect.no_equality(mapping.callback, nil)
  mapping.callback()
end

local function select_two_and_preview(cfg)
  merge_flow.start(cfg, { "First.md", "Nested/Second.md", "Third.md" })
  press("<Space>")
  press("j")
  press("<Space>")
  press("<CR>")
  press("<CR>")
end

T["selects notes in order, chooses a target, and opens an editable preview"] = function()
  local cfg = config.setup(helpers.valid())
  local content = {
    ["First.md"] = "---\ntags: [first]\n---\nFirst body\n",
    ["Nested/Second.md"] = "---\ntags: [second]\n---\nSecond body\n",
  }
  cli._set_executor(function(argv, _, callback)
    local path = argv[3]:gsub("^path=", "")
    if argv[2] == "read" then
      callback({ code = 0, stdout = content[path], stderr = "" })
    elseif argv[2] == "properties" then
      callback({
        code = 0,
        stdout = path == "First.md" and '{"tags":["first"]}' or '{"tags":["second"]}',
        stderr = "",
      })
    end
  end)

  select_two_and_preview(cfg)

  local active = merge_flow._current()
  MiniTest.expect.equality(active.mode, "preview")
  MiniTest.expect.equality(active.target, "First.md")
  MiniTest.expect.equality(active.ordered_paths, { "First.md", "Nested/Second.md" })
  MiniTest.expect.equality(vim.bo[active.view.buffers.body].modifiable, true)
  local preview =
    table.concat(vim.api.nvim_buf_get_lines(active.view.buffers.body, 0, -1, false), "\n")
  MiniTest.expect.equality(preview:find("## First", 1, true) ~= nil, true)
  MiniTest.expect.equality(preview:find("## Second", 1, true) ~= nil, true)
  MiniTest.expect.equality(preview:find("tags: [first]", 1, true), nil)
end

T["moves an explicitly chosen target first without reordering the other notes"] = function()
  local cfg = config.setup(helpers.valid())
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "read" then
      callback({ code = 0, stdout = argv[3] .. " body", stderr = "" })
    elseif argv[2] == "properties" then
      callback({ code = 0, stdout = "{}", stderr = "" })
    end
  end)

  merge_flow.start(cfg, { "First.md", "Second.md", "Third.md" })
  press("<Space>")
  press("j")
  press("<Space>")
  press("j")
  press("<Space>")
  press("<CR>")
  press("j")
  press("<CR>")

  local active = merge_flow._current()
  MiniTest.expect.equality(active.target, "Second.md")
  MiniTest.expect.equality(active.ordered_paths, { "Second.md", "First.md", "Third.md" })
end

T["requires confirmation before discarding an edited preview"] = function()
  local cfg = config.setup(helpers.valid())
  local completed
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "read" then
      callback({ code = 0, stdout = "body", stderr = "" })
    elseif argv[2] == "properties" then
      callback({ code = 0, stdout = "{}", stderr = "" })
    end
  end)
  ui._set_select(function(items, _, callback)
    MiniTest.expect.equality(items, { "Cancel", "Discard preview" })
    callback("Discard preview")
  end)

  merge_flow.start(cfg, { "First.md", "Second.md" }, {
    on_complete = function(result)
      completed = result
    end,
  })
  press("<Space>")
  press("j")
  press("<Space>")
  press("<CR>")
  press("<CR>")
  vim.api.nvim_buf_set_lines(merge_flow._current().view.buffers.body, -1, -1, false, { "edit" })
  press("<leader>oq")

  MiniTest.expect.equality(completed.status, "canceled")
  MiniTest.expect.equality(merge_flow._current(), nil)
end

T["intercepts an ordinary quit and routes it through safe preview cancellation"] = function()
  local cfg = config.setup(helpers.valid())
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "read" then
      callback({ code = 0, stdout = "body", stderr = "" })
    elseif argv[2] == "properties" then
      callback({ code = 0, stdout = "{}", stderr = "" })
    end
  end)
  ui._set_select(function(_, _, callback)
    callback("Discard preview")
  end)
  select_two_and_preview(cfg)
  local active = merge_flow._current()
  vim.api.nvim_buf_set_lines(active.view.buffers.body, -1, -1, false, { "edit" })

  local quit_ok = pcall(vim.cmd, "quit")
  vim.wait(100, function()
    return merge_flow._current() == nil
  end)

  MiniTest.expect.equality(quit_ok, false)
  MiniTest.expect.equality(merge_flow._current(), nil)
end

T["rechecks every snapshot before writing and trashing sources"] = function()
  local cfg = config.setup(helpers.valid())
  local content = {
    ["First.md"] = "First body\n",
    ["Nested/Second.md"] = "Second body\n",
  }
  local calls = {}
  local completed
  cli._set_executor(function(argv, _, callback)
    local path = argv[3] and argv[3]:gsub("^path=", "")
    table.insert(calls, { argv[2], path })
    if argv[2] == "read" then
      callback({ code = 0, stdout = content[path], stderr = "" })
    elseif argv[2] == "properties" then
      callback({ code = 0, stdout = "{}", stderr = "" })
    else
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end)

  merge_flow.start(cfg, { "First.md", "Nested/Second.md" }, {
    on_complete = function(result)
      completed = result
    end,
  })
  press("<Space>")
  press("j")
  press("<Space>")
  press("<CR>")
  press("<CR>")
  press("<leader>om")

  MiniTest.expect.equality(completed, {
    status = "merged",
    target = "First.md",
    sources = { "Nested/Second.md" },
  })
  MiniTest.expect.equality(
    vim.tbl_map(function(call)
      return call[1]
    end, calls),
    {
      "read",
      "properties",
      "read",
      "properties",
      "read",
      "read",
      "create",
      "delete",
    }
  )
end

T["refuses to save when a selected note changed after preview"] = function()
  local cfg = config.setup(helpers.valid())
  local reads = 0
  local writes = 0
  cli._set_executor(function(argv, _, callback)
    if argv[2] == "read" then
      reads = reads + 1
      callback({ code = 0, stdout = reads > 2 and "changed" or "original", stderr = "" })
    elseif argv[2] == "properties" then
      callback({ code = 0, stdout = "{}", stderr = "" })
    else
      writes = writes + 1
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end)

  select_two_and_preview(cfg)
  press("<leader>om")

  MiniTest.expect.equality(writes, 0)
  MiniTest.expect.equality(merge_flow._current().mode, "preview")
  MiniTest.expect.equality(merge_flow._current().pending, false)
end

T["refuses to read a selected note with unsaved Neovim changes"] = function()
  local cfg = config.setup(helpers.valid())
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  vim.fn.writefile({ "disk" }, root .. "/First.md")
  local buffer = vim.fn.bufadd(root .. "/First.md")
  vim.fn.bufload(buffer)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "unsaved" })
  vim.bo[buffer].modified = true
  local cli_calls = 0
  cli._set_executor(function(_, _, callback)
    cli_calls = cli_calls + 1
    callback({ code = 0, stdout = "", stderr = "" })
  end)

  merge_flow.start(cfg, { "First.md", "Second.md" }, { vault_root = root })
  press("<Space>")
  press("j")
  press("<Space>")
  press("<CR>")
  press("<CR>")

  MiniTest.expect.equality(cli_calls, 0)
  MiniTest.expect.equality(merge_flow._current().mode, "target")
  MiniTest.expect.equality(merge_flow._current().pending, false)
  vim.bo[buffer].modified = false
  vim.api.nvim_buf_delete(buffer, { force = true })
  vim.fn.delete(root, "rf")
end

return T
