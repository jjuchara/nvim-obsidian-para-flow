local config = require("obsidian-para-flow.config")

local M = {}
local installed_mappings = {}
local commands_registered = false
local categories = { "inbox", "projects", "areas", "resources", "archives" }

-- `find` keys mirror the Home section keys: p/a/r/x plus i for Inbox.
local find_keys = {
  f = false,
  i = "inbox",
  p = "projects",
  a = "areas",
  r = "resources",
  x = "archives",
}

local function complete_category(argument)
  return vim.tbl_filter(function(value)
    return vim.startswith(value, argument)
  end, categories)
end

local function category_argument(arguments)
  local category = vim.trim(arguments.args or "")
  if category == "" then
    return nil
  end
  if not vim.tbl_contains(categories, category) then
    error("obsidian-para-flow: unknown category `" .. category .. "`", 0)
  end
  return category
end

local function register_commands()
  if commands_registered then
    return
  end
  vim.api.nvim_create_user_command("ObsidianParaFind", function(arguments)
    M.find(category_argument(arguments))
  end, { nargs = "?", complete = complete_category })
  vim.api.nvim_create_user_command("ObsidianParaGrep", function(arguments)
    M.grep(category_argument(arguments))
  end, { nargs = "?", complete = complete_category })
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

local function map_find(prefix)
  if prefix == false then
    return
  end
  for key, category in pairs(find_keys) do
    map(prefix .. key, function()
      M.find(category or nil)
    end, "Obsidian PARA: find notes in " .. (category or "the vault"))
  end
  map(prefix .. "g", function()
    M.grep()
  end, "Obsidian PARA: search vault contents")
  map(prefix .. "G", function()
    M.grep_prompt()
  end, "Obsidian PARA: search a PARA section")
end

local function register_which_key_group(cfg)
  local function belongs_to_group(lhs)
    return type(lhs) == "string" and vim.startswith(lhs, "<leader>o")
  end

  if
    not belongs_to_group(cfg.mappings.home)
    and not belongs_to_group(cfg.mappings.new)
    and not belongs_to_group(cfg.mappings.review)
    and not belongs_to_group(cfg.mappings.find)
  then
    return
  end

  local ok, which_key = pcall(require, "which-key")
  if ok and type(which_key.add) == "function" then
    -- selene: allow(mixed_table)
    local groups = {
      {
        "<leader>o",
        group = "obsidian para flow",
        icon = { icon = "◆ ", color = "purple" },
      },
    }
    if belongs_to_group(cfg.mappings.find) then
      -- selene: allow(mixed_table)
      table.insert(
        groups,
        { cfg.mappings.find, group = "find", icon = { icon = "󰍉 ", color = "purple" } }
      )
    end
    which_key.add(groups)
  end
end

function M.setup(options)
  local cfg = config.setup(options)
  register_commands()
  clear_mappings()
  map(cfg.mappings.home, M.home, "Obsidian PARA: open Home")
  map(cfg.mappings.new, M.inbox_new, "Obsidian PARA: new Inbox note")
  map(cfg.mappings.review, M.inbox_review, "Obsidian PARA: review Inbox")
  map_find(cfg.mappings.find)
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

function M.find(category)
  require("obsidian-para-flow.picker").files(config.get(), category)
end

function M.grep(category)
  require("obsidian-para-flow.picker").grep(config.get(), category)
end

function M.grep_prompt()
  local ui = require("obsidian-para-flow.ui")
  ui.select(categories, { prompt = "Search which section: " }, function(category)
    if category then
      M.grep(category)
    end
  end)
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
