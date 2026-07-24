local helpers = require("tests.helpers.config")
local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local rename = require("obsidian-para-flow.rename")
local ui = require("obsidian-para-flow.ui")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      cli._reset()
      config._reset()
      rename._reset()
      ui._reset()
    end,
    post_case = function()
      cli._reset()
      rename._reset()
      ui._reset()
    end,
  },
})

T["renames a note in place after validating the new basename"] = function()
  local cfg = config.setup(helpers.valid())
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/Folder", "p")
  local argv
  cli._set_executor(function(value, _, callback)
    argv = value
    callback({ code = 0, stdout = "", stderr = "" })
  end)
  ui._set_input(function(options, callback)
    MiniTest.expect.equality(options.default, "Old")
    callback("Новое имя.md")
  end)
  local result

  MiniTest.expect.equality(
    rename.start(cfg, "Folder/Old.md", { vault_root = root }, function(value)
      result = value
    end),
    true
  )

  MiniTest.expect.equality(argv, {
    "obsidian",
    "rename",
    "path=Folder/Old.md",
    "name=Новое имя",
    "vault=Test Vault",
  })
  MiniTest.expect.equality(result.status, "renamed")
  MiniTest.expect.equality(result.path, "Folder/Новое имя.md")
  vim.fn.delete(root, "rf")
end

T["rejects path separators and an existing destination before the CLI mutation"] = function()
  local cfg = config.setup(helpers.valid())
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/Folder", "p")
  vim.fn.writefile({ "existing" }, root .. "/Folder/Taken.md")
  local calls = 0
  cli._set_executor(function()
    calls = calls + 1
  end)

  local values = { "Nested/Name", "Taken" }
  for index, expected in ipairs({ "error", "conflict" }) do
    ui._set_input(function(_, callback)
      callback(values[index])
    end)
    local result
    rename.start(cfg, "Folder/Old.md", { vault_root = root }, function(value)
      result = value
    end)
    MiniTest.expect.equality(result.status, expected)
  end
  MiniTest.expect.equality(calls, 0)
  vim.fn.delete(root, "rf")
end

T["blocks rename while the selected note has unsaved changes"] = function()
  local cfg = config.setup(helpers.valid())
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  local path = root .. "/Old.md"
  vim.fn.writefile({ "saved" }, path)
  local buffer = vim.fn.bufadd(path)
  vim.fn.bufload(buffer)
  vim.bo[buffer].modified = true

  MiniTest.expect.equality(rename.start(cfg, "Old.md", { vault_root = root }), false)

  vim.api.nvim_buf_delete(buffer, { force = true })
  vim.fn.delete(root, "rf")
end

T["keeps a loaded unmodified Neovim buffer attached to the renamed path"] = function()
  local cfg = config.setup(helpers.valid())
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  local source = root .. "/Old.md"
  vim.fn.writefile({ "saved" }, source)
  local buffer = vim.fn.bufadd(source)
  vim.fn.bufload(buffer)
  cli._set_executor(function(_, _, callback)
    callback({ code = 0, stdout = "", stderr = "" })
  end)
  ui._set_input(function(_, callback)
    callback("New")
  end)

  rename.start(cfg, "Old.md", { vault_root = root })

  MiniTest.expect.equality(vim.api.nvim_buf_get_name(buffer), vim.uv.fs_realpath(root) .. "/New.md")
  vim.api.nvim_buf_delete(buffer, { force = true })
  vim.fn.delete(root, "rf")
end

return T
