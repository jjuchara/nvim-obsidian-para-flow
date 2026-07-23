local helpers = require("tests.helpers.config")
local config = require("obsidian-para-flow.config")
local health = require("obsidian-para-flow.health")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      config._reset()
      config.setup(helpers.valid())
    end,
  },
})

T["collects read-only vault QuickAdd and folder checks"] = function()
  local calls = {}
  local adapter = {}
  adapter.version = function(_, callback)
    table.insert(calls, "version")
    callback({ ok = true, stdout = "1.12.7" })
  end
  adapter.vault_info = function(_, field, callback)
    table.insert(calls, "vault:" .. field)
    callback({ ok = true, stdout = "Test Vault" })
  end
  adapter.quickadd_check = function(_, choice, callback)
    table.insert(calls, "quickadd:check:" .. choice)
    callback({ ok = true, data = { choice = { name = choice } } })
  end
  adapter.folder_info = function(_, folder, callback)
    table.insert(calls, "folder:" .. folder)
    callback({ ok = true, stdout = folder })
  end

  local checks
  health.collect(function(value)
    checks = value
  end, { cli = adapter, skip_executable = true })

  MiniTest.expect.equality(#checks, 11)
  MiniTest.expect.equality(checks[2].name, "Picker")
  MiniTest.expect.equality(checks[3].name, "ripgrep")
  MiniTest.expect.equality(calls[1], "version")
  MiniTest.expect.equality(calls[2], "vault:name")
  MiniTest.expect.equality(calls[3], "quickadd:check:inbox")
end

T["checks every capture profile choice and folder"] = function()
  local options = helpers.valid()
  options.capture = {
    profiles = {
      meeting = {
        folder = "3. Resources/Meetings",
        quickadd_choice = "meeting",
      },
    },
  }
  config.setup(options)
  local calls = {}
  local adapter = {
    version = function(_, callback)
      callback({ ok = true, stdout = "1.12.7" })
    end,
    vault_info = function(_, _, callback)
      callback({ ok = true, stdout = "Test Vault" })
    end,
    quickadd_check = function(_, choice, callback)
      table.insert(calls, "choice:" .. choice)
      callback({ ok = true, data = { choice = { name = choice } } })
    end,
    folder_info = function(_, folder, callback)
      table.insert(calls, "folder:" .. folder)
      callback({ ok = true, stdout = folder })
    end,
  }

  health.collect(function() end, { cli = adapter, skip_executable = true })

  MiniTest.expect.equality(vim.tbl_contains(calls, "choice:meeting"), true)
  MiniTest.expect.equality(vim.tbl_contains(calls, "folder:3. Resources/Meetings"), true)
end

return T
