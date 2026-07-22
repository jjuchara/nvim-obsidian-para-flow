local helpers = require("tests.helpers.config")
local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local vault = require("obsidian-para-flow.vault")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      cli._reset()
      config._reset()
      vault._reset()
    end,
    post_case = function()
      cli._reset()
      vault._reset()
    end,
  },
})

local function counting_executor(counter, stdout)
  return function(_, _, callback)
    counter.calls = counter.calls + 1
    callback({ code = 0, stdout = stdout, stderr = "" })
  end
end

T["resolves the vault root once and serves it from cache"] = function()
  local cfg = config.setup(helpers.valid())
  local counter = { calls = 0 }
  cli._set_executor(counting_executor(counter, "/tmp/test-vault"))

  local first, second
  vault.root(cfg, function(result)
    first = result
  end)
  vault.root(cfg, function(result)
    second = result
  end)

  MiniTest.expect.equality(first, { ok = true, root = "/tmp/test-vault" })
  MiniTest.expect.equality(second, { ok = true, root = "/tmp/test-vault" })
  MiniTest.expect.equality(counter.calls, 1)
end

T["bypasses the cache when asked to refresh"] = function()
  local cfg = config.setup(helpers.valid())
  local counter = { calls = 0 }
  cli._set_executor(counting_executor(counter, "/tmp/test-vault"))

  vault.root(cfg, function() end)
  vault.root(cfg, function() end, { refresh = true })
  MiniTest.expect.equality(counter.calls, 2)
end

T["joins PARA folders onto the vault root"] = function()
  local cfg = config.setup(helpers.valid())
  cli._set_executor(counting_executor({ calls = 0 }, "/tmp/test-vault"))

  local resources, inbox, whole
  vault.folder(cfg, "resources", function(result)
    resources = result
  end)
  vault.folder(cfg, "inbox", function(result)
    inbox = result
  end)
  vault.folder(cfg, nil, function(result)
    whole = result
  end)

  MiniTest.expect.equality(resources.root, "/tmp/test-vault/3. Resources")
  MiniTest.expect.equality(inbox.root, "/tmp/test-vault/6. Inbox")
  MiniTest.expect.equality(whole.root, "/tmp/test-vault")
end

T["reports an empty vault path as an error and does not cache it"] = function()
  local cfg = config.setup(helpers.valid())
  local counter = { calls = 0 }
  cli._set_executor(counting_executor(counter, ""))

  local result
  vault.root(cfg, function(value)
    result = value
  end)
  MiniTest.expect.equality(result.ok, false)

  vault.root(cfg, function() end)
  MiniTest.expect.equality(counter.calls, 2)
end

return T
