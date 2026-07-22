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
  vim.api.nvim_create_user_command("ObsidianParaHome", function()
    M.home()
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

local function register_which_key_group(cfg)
  local function belongs_to_group(lhs)
    return type(lhs) == "string" and vim.startswith(lhs, "<leader>o")
  end

  if
    not belongs_to_group(cfg.mappings.home)
    and not belongs_to_group(cfg.mappings.new)
    and not belongs_to_group(cfg.mappings.review)
  then
    return
  end

  local ok, which_key = pcall(require, "which-key")
  if ok and type(which_key.add) == "function" then
    -- selene: allow(mixed_table)
    which_key.add({
      {
        "<leader>o",
        group = "obsidian para flow",
        icon = { icon = "◆ ", color = "purple" },
      },
    })
  end
end

function M.setup(options)
  local cfg = config.setup(options)
  register_commands()
  clear_mappings()
  map(cfg.mappings.home, M.home, "Obsidian PARA: open Home")
  map(cfg.mappings.new, M.inbox_new, "Obsidian PARA: new Inbox note")
  map(cfg.mappings.review, M.inbox_review, "Obsidian PARA: review Inbox")
  register_which_key_group(cfg)
  return cfg
end

function M.home()
  require("obsidian-para-flow.home").start()
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
  local home = package.loaded["obsidian-para-flow.home"]
  if home then
    home._reset()
  end
  config._reset()
end

return M
