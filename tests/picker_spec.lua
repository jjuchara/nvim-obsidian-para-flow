local helpers = require("tests.helpers.config")
local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local picker = require("obsidian-para-flow.picker")
local ui = require("obsidian-para-flow.ui")
local vault = require("obsidian-para-flow.vault")

local backend_modules = { "snacks", "fzf-lua", "fzf-lua.actions", "telescope.builtin" }

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      cli._reset()
      config._reset()
      ui._reset()
      vault._reset()
      for _, name in ipairs(backend_modules) do
        package.loaded[name] = nil
      end
      cli._set_executor(function(_, _, callback)
        callback({ code = 0, stdout = "/tmp/test-vault", stderr = "" })
      end)
    end,
    post_case = function()
      cli._reset()
      ui._reset()
      vault._reset()
      for _, name in ipairs(backend_modules) do
        package.loaded[name] = nil
      end
    end,
  },
})

local function record_calls()
  return setmetatable({}, {
    __index = function(recorded, key)
      local call = function(options)
        rawset(recorded, key, options)
      end
      return call
    end,
  })
end

local function install_snacks(recorded)
  package.loaded["snacks"] = { picker = recorded }
end

T["prefers snacks and scopes it to the section folder"] = function()
  local cfg = config.setup(helpers.valid())
  local recorded = {}
  install_snacks({
    files = function(options)
      recorded.files = options
    end,
    grep = function(options)
      recorded.grep = options
    end,
  })

  MiniTest.expect.equality(picker.backend(cfg), "snacks")
  picker.files(cfg, "resources")
  MiniTest.expect.equality(recorded.files.cwd, "/tmp/test-vault/3. Resources")
  MiniTest.expect.equality(recorded.files.ft, "md")
  MiniTest.expect.equality(recorded.files.confirm, "tab")

  picker.grep(cfg, nil)
  MiniTest.expect.equality(recorded.grep.cwd, "/tmp/test-vault")
  MiniTest.expect.equality(recorded.grep.glob, "*.md")
  MiniTest.expect.equality(recorded.grep.confirm, "tab")
end

T["keeps the current tab when search starts from a vault buffer"] = function()
  local cfg = config.setup(helpers.valid())
  local recorded = {}
  install_snacks({
    files = function(options)
      recorded.files = options
    end,
  })
  local origin_buffer = vim.api.nvim_get_current_buf()
  local vault_buffer = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(vault_buffer, "/tmp/test-vault/Current.md")
  vim.api.nvim_win_set_buf(0, vault_buffer)

  picker.files(cfg)

  MiniTest.expect.equality(recorded.files.confirm, nil)
  vim.api.nvim_win_set_buf(0, origin_buffer)
  vim.api.nvim_buf_delete(vault_buffer, { force = true })
end

T["falls back through fzf-lua and telescope"] = function()
  local cfg = config.setup(helpers.valid())
  local fzf = record_calls()
  package.loaded["fzf-lua"] = fzf
  package.loaded["fzf-lua.actions"] = { file_tabedit = function() end }
  MiniTest.expect.equality(picker.backend(cfg), "fzf-lua")
  picker.files(cfg, "projects")
  MiniTest.expect.equality(fzf.files.cwd, "/tmp/test-vault/1. Projects")
  MiniTest.expect.no_equality(fzf.files.actions.default, nil)

  package.loaded["fzf-lua"] = nil
  local telescope = record_calls()
  package.loaded["telescope.builtin"] = telescope
  MiniTest.expect.equality(picker.backend(cfg), "telescope")
  picker.grep(cfg, "archives")
  MiniTest.expect.equality(telescope.live_grep.cwd, "/tmp/test-vault/4. Archives")
  MiniTest.expect.equality(telescope.live_grep.glob_pattern, "*.md")
end

T["honors an explicit provider over an installed picker"] = function()
  local options = helpers.valid()
  options.search = { provider = "builtin" }
  local cfg = config.setup(options)
  install_snacks(record_calls())
  MiniTest.expect.equality(picker.backend(cfg), "builtin")
end

T["falls back to builtin when the requested provider is missing"] = function()
  local options = helpers.valid()
  options.search = { provider = "telescope" }
  local cfg = config.setup(options)
  MiniTest.expect.equality(picker.backend(cfg), "builtin")
end

T["builtin file search lists Markdown notes below the scoped folder"] = function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/3. Resources/Nested", "p")
  vim.fn.writefile({ "" }, root .. "/3. Resources/Ресурсы.md")
  vim.fn.writefile({ "" }, root .. "/3. Resources/Nested/Deep.md")
  vim.fn.writefile({ "" }, root .. "/3. Resources/ignored.txt")
  vim.fn.writefile({ "" }, root .. "/Outside.md")

  cli._reset()
  cli._set_executor(function(_, _, callback)
    callback({ code = 0, stdout = root, stderr = "" })
  end)

  local options = helpers.valid()
  options.search = { provider = "builtin" }
  local cfg = config.setup(options)

  local offered
  ui._set_select(function(items, _, callback)
    offered = items
    callback(nil)
  end)
  picker.files(cfg, "resources")

  MiniTest.expect.equality(offered, { "Nested/Deep.md", "Ресурсы.md" })
  vim.fn.delete(root, "rf")
end

T["keeps a non-vault buffer intact by opening a builtin result in a new tab"] = function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  vim.fn.writefile({ "# Note" }, root .. "/Note.md")

  cli._reset()
  cli._set_executor(function(_, _, callback)
    callback({ code = 0, stdout = root, stderr = "" })
  end)

  local options = helpers.valid()
  options.search = { provider = "builtin" }
  local cfg = config.setup(options)
  local origin_buffer = vim.api.nvim_get_current_buf()
  local tabs = #vim.api.nvim_list_tabpages()
  ui._set_select(function(_, _, callback)
    callback("Note.md")
  end)

  picker.files(cfg)

  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), vim.uv.fs_realpath(root .. "/Note.md"))
  MiniTest.expect.equality(vim.api.nvim_buf_is_valid(origin_buffer), true)
  vim.cmd("tabclose")
  vim.fn.delete(root, "rf")
end

return T
