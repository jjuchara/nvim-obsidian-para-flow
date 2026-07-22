local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local home_loader = require("obsidian-para-flow.home_loader")

local T = MiniTest.new_set()

local function await(start)
  local result
  start(function(value)
    result = value
  end)
  MiniTest.expect.equality(
    vim.wait(20000, function()
      return result ~= nil
    end, 20),
    true
  )
  return result
end

local function expect_ok(result, operation)
  if not result.ok then
    error(("%s failed: %s"):format(operation, result.message or result.stderr or "unknown error"))
  end
end

T["uses only the explicitly selected test vault"] = function()
  local vault = vim.env.OBSIDIAN_PARA_TEST_VAULT
  MiniTest.expect.equality(type(vault), "string")
  MiniTest.expect.no_equality(vault, "")

  local result = await(function(callback)
    cli.ensure_vault(vault, callback)
  end)
  expect_ok(result, "test vault identity check")
  MiniTest.expect.equality(result.stdout, vault)
end

T["loads every Home section read-only from the selected test vault"] = function()
  local vault = assert(
    vim.env.OBSIDIAN_PARA_TEST_VAULT,
    "OBSIDIAN_PARA_TEST_VAULT is required for integration tests"
  )
  local cfg = config.setup({
    vault = vault,
    inbox = { folder = "6. Inbox", quickadd_choice = "inbox" },
    para = {
      projects = { folder = "1. Projects", link = "[[My Projects]]" },
      areas = { folder = "2. Areas", link = "[[My Areas]]" },
      resources = { folder = "3. Resources" },
      archives = { folder = "4. Archives" },
    },
  })

  for _, category in ipairs({ "inbox", "projects", "areas", "resources", "archives" }) do
    local result = await(function(callback)
      home_loader.load_section(cfg, category, callback)
    end)
    expect_ok(result, "Home " .. category .. " read")
    MiniTest.expect.equality(result.data.category, category)
  end
end

T["creates moves reads and trashes only a marked fixture"] = function()
  local vault = assert(
    vim.env.OBSIDIAN_PARA_TEST_VAULT,
    "OBSIDIAN_PARA_TEST_VAULT is required for integration tests"
  )
  local inbox = vim.env.OBSIDIAN_PARA_TEST_INBOX or "6. Inbox"
  local archives = vim.env.OBSIDIAN_PARA_TEST_ARCHIVES or "4. Archives"
  local nonce = ("%d-%d"):format(os.time(), vim.fn.getpid())
  local name = "__obsidian-para-flow-integration-" .. nonce .. ".md"
  local source = inbox .. "/" .. name
  local destination = archives .. "/" .. name
  local content = table.concat({
    "---",
    "obsidian_para_flow_fixture: true",
    "obsidian_para_flow_run: " .. nonce,
    "---",
    "",
    "# obsidian-para-flow integration fixture",
    "",
    "Safe to move to trash after the integration gate.",
  }, "\n")
  local created = false

  local ok, failure = pcall(function()
    local identity = await(function(callback)
      cli.ensure_vault(vault, callback)
    end)
    expect_ok(identity, "test vault identity check")

    local create = await(function(callback)
      cli.create(vault, source, content, callback)
    end)
    expect_ok(create, "marked fixture creation")
    created = true

    local source_read = await(function(callback)
      cli.read(vault, source, callback)
    end)
    expect_ok(source_read, "marked fixture read")
    MiniTest.expect.equality(source_read.stdout, content)

    local move = await(function(callback)
      cli.move(vault, source, destination, callback)
    end)
    expect_ok(move, "marked fixture move")

    local destination_read = await(function(callback)
      cli.read(vault, destination, callback)
    end)
    expect_ok(destination_read, "moved fixture read")
    MiniTest.expect.equality(destination_read.stdout, content)

    local trash = await(function(callback)
      cli.trash(vault, destination, callback)
    end)
    expect_ok(trash, "marked fixture trash")
    created = false
  end)

  if created then
    await(function(callback)
      cli.trash(vault, source, function(source_result)
        if source_result.ok then
          callback(source_result)
          return
        end
        cli.trash(vault, destination, callback)
      end)
    end)
  end

  if not ok then
    error(failure)
  end
end

return T
