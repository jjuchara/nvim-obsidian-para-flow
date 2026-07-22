local config = require("obsidian-para-flow.config")

local M = {}
local installed_mappings = {}
local commands_registered = false

local function register_commands()
  if commands_registered then
    return
  end
  vim.api.nvim_create_user_command("ObsidianParaInboxNew", function()
    M.inbox_new()
  end, {})
  vim.api.nvim_create_user_command("ObsidianParaInboxReview", function()
    M.inbox_review()
  end, {})
  vim.api.nvim_create_user_command("ObsidianParaHealth", function()
    M.health()
  end, {})
  commands_registered = true
end

local function clear_mappings()
  for _, lhs in ipairs(installed_mappings) do
    pcall(vim.keymap.del, "n", lhs)
  end
  installed_mappings = {}
end

local function map(lhs, rhs, description)
  if lhs == false then
    return
  end
  vim.keymap.set("n", lhs, rhs, { desc = description, silent = true })
  table.insert(installed_mappings, lhs)
end

function M.setup(options)
  local cfg = config.setup(options)
  register_commands()
  clear_mappings()
  map(cfg.mappings.new, M.inbox_new, "Obsidian PARA: new Inbox note")
  map(cfg.mappings.review, M.inbox_review, "Obsidian PARA: review Inbox")
  return cfg
end

function M.inbox_new()
  require("obsidian-para-flow.inbox").new()
end

function M.inbox_review()
  require("obsidian-para-flow.review").start()
end

function M.health()
  require("obsidian-para-flow.health").run()
end

function M._register_commands()
  register_commands()
end

function M._reset()
  clear_mappings()
  config._reset()
end

return M
