local helpers = require("tests.helpers.config")
local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local integration = require("obsidian-para-flow.task_integration")
local ui = require("obsidian-para-flow.ui")
local vault = require("obsidian-para-flow.vault")
local original_notify = vim.notify

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      integration._reset()
      config._reset()
      cli._reset()
      ui._reset()
      vault._reset()
      vim.notify = original_notify
      config.setup(helpers.valid())
    end,
    post_case = function()
      integration._reset()
      cli._reset()
      ui._reset()
      vault._reset()
      vim.notify = original_notify
    end,
  },
})

T["builds and resolves a move-friendly linked-note completion marker"] = function()
  local suffix = integration.description_suffix("6. Inbox/New note.md", true, true)
  MiniTest.expect.equality(
    suffix,
    "[[6. Inbox/New note]] <!-- obsidian-para-flow:expire-on-complete -->"
  )
  MiniTest.expect.equality(integration.linked_path(suffix), "6. Inbox/New note.md")
  MiniTest.expect.equality(
    integration.linked_path(
      "text [[3. Resources/New place|New note]] <!-- obsidian-para-flow:expire-on-complete -->"
    ),
    "3. Resources/New place.md"
  )
  MiniTest.expect.equality(integration.description_suffix("Note.md", false, true), nil)
  MiniTest.expect.equality(
    integration.linked_path("[[../unsafe]] <!-- obsidian-para-flow:expire-on-complete -->"),
    nil
  )
end

T["registers one completion listener and supports cleanup"] = function()
  local registered = 0
  local removed = 0
  local tasks = {
    on_toggle = function(callback)
      MiniTest.expect.equality(callback, integration.handle_toggle)
      registered = registered + 1
      return function()
        removed = removed + 1
      end
    end,
  }

  MiniTest.expect.equality(integration.register(tasks), true)
  MiniTest.expect.equality(integration.register(tasks), true)
  MiniTest.expect.equality(registered, 1)
  integration._reset()
  MiniTest.expect.equality(removed, 1)
end

T["sets expired_at after a linked task is completed"] = function()
  local calls = {}
  cli._set_executor(function(argv, _, callback)
    calls[#calls + 1] = argv
    if argv[2] == "vault" then
      callback({
        code = 0,
        stdout = argv[3] == "info=path" and "/tmp/Test Vault" or "Test Vault",
        stderr = "",
      })
    elseif argv[2] == "properties" then
      callback({ code = 0, stdout = "{}", stderr = "" })
    elseif argv[2] == "property:set" then
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end)

  integration.handle_toggle({
    done = true,
    task = {
      text = "New [[6. Inbox/New]] <!-- obsidian-para-flow:expire-on-complete -->",
    },
  })

  MiniTest.expect.equality(#calls, 4)
  MiniTest.expect.equality(calls[3], {
    "obsidian",
    "property:set",
    "path=6. Inbox/New.md",
    "name=expired_at",
    "value=" .. require("obsidian-para-flow.date").today(),
    "type=date",
    "vault=Test Vault",
  })
end

T["refreshes a clean loaded note buffer after completion"] = function()
  local root = vim.fn.tempname()
  local relative = "6. Inbox/New.md"
  local path = vim.fs.joinpath(root, relative)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ "# New" }, path)
  vim.cmd.edit(vim.fn.fnameescape(path))

  cli._set_executor(function(argv, _, callback)
    if argv[2] == "vault" and argv[3] == "info=name" then
      callback({ code = 0, stdout = "Test Vault", stderr = "" })
    elseif argv[2] == "properties" then
      callback({ code = 0, stdout = "{}", stderr = "" })
    elseif argv[2] == "property:set" then
      vim.fn.writefile(
        { "---", "expired_at: " .. require("obsidian-para-flow.date").today(), "---", "# New" },
        path
      )
      callback({ code = 0, stdout = "", stderr = "" })
    elseif argv[2] == "vault" and argv[3] == "info=path" then
      callback({ code = 0, stdout = root, stderr = "" })
    end
  end)

  integration.handle_toggle({
    done = true,
    task = { text = "[[6. Inbox/New]] <!-- obsidian-para-flow:expire-on-complete -->" },
  })

  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, 0, 3, false), {
    "---",
    "expired_at: " .. require("obsidian-para-flow.date").today(),
    "---",
  })
  vim.cmd("bwipeout!")
end

T["preserves a modified loaded note buffer and warns after completion"] = function()
  local root = vim.fn.tempname()
  local relative = "6. Inbox/New.md"
  local path = vim.fs.joinpath(root, relative)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ "# New" }, path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "local change" })
  local notifications = {}
  vim.notify = function(message, level)
    notifications[#notifications + 1] = { message = message, level = level }
  end

  cli._set_executor(function(argv, _, callback)
    if argv[2] == "vault" and argv[3] == "info=name" then
      callback({ code = 0, stdout = "Test Vault", stderr = "" })
    elseif argv[2] == "properties" then
      callback({ code = 0, stdout = "{}", stderr = "" })
    elseif argv[2] == "property:set" then
      vim.fn.writefile(
        { "---", "expired_at: " .. require("obsidian-para-flow.date").today(), "---", "# New" },
        path
      )
      callback({ code = 0, stdout = "", stderr = "" })
    elseif argv[2] == "vault" and argv[3] == "info=path" then
      callback({ code = 0, stdout = root, stderr = "" })
    end
  end)

  integration.handle_toggle({
    done = true,
    task = { text = "[[6. Inbox/New]] <!-- obsidian-para-flow:expire-on-complete -->" },
  })

  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(0, -2, -1, false), { "local change" })
  MiniTest.expect.equality(notifications[1], {
    message = "obsidian-para-flow: set expired_at for `6. Inbox/New.md`, but its modified buffer was not reloaded",
    level = vim.log.levels.WARN,
  })
  vim.cmd("bwipeout!")
end

T["preserves an existing expiration and ignores reopen, project, or archived notes"] = function()
  local calls = 0
  cli._set_executor(function(argv, _, callback)
    calls = calls + 1
    if argv[2] == "vault" then
      callback({ code = 0, stdout = "Test Vault", stderr = "" })
    elseif argv[2] == "properties" then
      callback({ code = 0, stdout = '{"expired_at":"2030-01-01"}', stderr = "" })
    else
      error("unexpected mutation")
    end
  end)

  integration.handle_toggle({
    done = false,
    task = { text = "[[6. Inbox/New]] <!-- obsidian-para-flow:expire-on-complete -->" },
  })
  integration.handle_toggle({
    done = true,
    task = { text = "[[4. Archives/New]] <!-- obsidian-para-flow:expire-on-complete -->" },
  })
  integration.handle_toggle({
    done = true,
    task = { text = "[[1. Projects/New]] <!-- obsidian-para-flow:expire-on-complete -->" },
  })
  integration.handle_toggle({
    done = true,
    task = { text = "[[6. Inbox/New]] <!-- obsidian-para-flow:expire-on-complete -->" },
  })

  MiniTest.expect.equality(calls, 2)
end

return T
