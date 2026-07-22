local config = require("obsidian-para-flow.config")
local filter_input = require("obsidian-para-flow.filter_input")
local loader = require("obsidian-para-flow.home_loader")
local model = require("obsidian-para-flow.home_model")
local picker = require("obsidian-para-flow.picker")
local ui = require("obsidian-para-flow.ui")
local home_ui = require("obsidian-para-flow.home_ui")
local vault = require("obsidian-para-flow.vault")

local M = {}
local current
local refresh
local getchar = vim.fn.getcharstr
local last_state = {
  active_section = "projects",
  selections = { inbox = 1, projects = 1, areas = 1, resources = 1, archives = 1 },
}
local categories = { "inbox", "projects", "areas", "resources", "archives" }

local function notify_error(message)
  ui.notify_error(message)
end

local function render(active)
  if current == active and active.view:is_valid() then
    active.view:render(active)
  end
end

local function section_items(active, category)
  local section = active.sections[category]
  if section.status ~= "ready" then
    return {}
  end
  if active.mode == category then
    return model.grouped(section.data, active.filter)
  end
  local items = {}
  for index = 1, math.min(active.preview_limit, #section.data.items) do
    table.insert(items, section.data.items[index])
  end
  return items
end

local function clamp_selection(active, category)
  local items = section_items(active, category)
  active.selections[category] =
    math.max(1, math.min(active.selections[category] or 1, math.max(1, #items)))
  return items
end

local function selected_item(active)
  local items = clamp_selection(active, active.active_section)
  return items[active.selections[active.active_section]]
end

local function close(active)
  if current ~= active then
    return
  end
  active.generation = active.generation + 1
  last_state.active_section = active.active_section
  last_state.selections = vim.deepcopy(active.selections)
  current = nil
  active.view:close()
end

local function open_selected(active)
  local item = selected_item(active)
  if not item then
    return
  end
  if not active.vault_root then
    notify_error(active.vault_error or "The vault path is still loading")
    return
  end
  local full_path = vim.fs.joinpath(active.vault_root, item.path)
  if not vim.uv.fs_stat(full_path) then
    notify_error("Home note no longer exists: " .. item.path)
    refresh(active)
    return
  end
  local buffer = vim.fn.bufadd(full_path)
  local ok, error_message = pcall(vim.fn.bufload, buffer)
  if not ok then
    notify_error("Could not open Home note: " .. tostring(error_message))
    return
  end
  vim.bo[buffer].buflisted = true
  close(active)
  vim.api.nvim_win_set_buf(0, buffer)
end

refresh = function(active)
  active.generation = active.generation + 1
  local generation = active.generation
  active.filter = ""
  for _, category in ipairs(categories) do
    active.sections[category] = { status = "loading" }
  end
  render(active)
  vault.root(active.cfg, function(path_result)
    if current ~= active or active.generation ~= generation then
      return
    end
    if not path_result.ok then
      active.vault_root = nil
      active.vault_error = path_result.message
      for _, category in ipairs(categories) do
        active.sections[category] = {
          status = "error",
          message = active.vault_error,
        }
      end
      render(active)
      return
    end
    active.vault_root = path_result.root
    active.vault_error = nil
    loader.load_all(active.cfg, function(category, result)
      if current ~= active or active.generation ~= generation then
        return
      end
      if result.ok then
        active.sections[category] = { status = "ready", data = result.data }
        clamp_selection(active, category)
      else
        active.sections[category] = {
          status = "error",
          message = result.message or ("Could not load " .. category),
        }
      end
      render(active)
    end)
  end, { refresh = true })
end

local function move(active, delta)
  local items = clamp_selection(active, active.active_section)
  if #items == 0 then
    return
  end
  active.selections[active.active_section] =
    math.max(1, math.min(#items, active.selections[active.active_section] + delta))
  render(active)
end

local function switch_section(active, delta)
  local index = 1
  for candidate, category in ipairs(categories) do
    if category == active.active_section then
      index = candidate
      break
    end
  end
  index = ((index - 1 + delta) % #categories) + 1
  active.active_section = categories[index]
  if active.mode ~= "overview" then
    active.mode = active.active_section
    active.filter = ""
    clamp_selection(active, active.active_section)
  end
  render(active)
end

local function enter_section(active, category)
  active.mode = category
  active.active_section = category
  active.filter = ""
  clamp_selection(active, category)
  render(active)
end

local function set_filter(active, query)
  active.filter = query
  active.selections[active.active_section] = 1
  render(active)
  vim.cmd("redraw")
end

-- Reads keys one at a time so the list narrows as the user types, the way
-- Obsidian's quick switcher does. Key handling itself lives in filter_input.
local function filter(active)
  if active.mode == "overview" then
    vim.notify("obsidian-para-flow: Open a full PARA section before filtering", vim.log.levels.INFO)
    return
  end
  local restore = active.filter
  active.filtering = true
  set_filter(active, active.filter)
  while true do
    local ok, key = pcall(getchar)
    local step = filter_input.apply(active.filter, ok and key or "\27")
    if step.action == "cancel" then
      active.filtering = false
      set_filter(active, restore)
      return
    end
    if step.action == "accept" then
      active.filtering = false
      set_filter(active, step.query)
      return
    end
    if current ~= active then
      active.filtering = false
      return
    end
    set_filter(active, step.query)
  end
end

local function escape(active)
  if active.filter ~= "" then
    active.filter = ""
    active.selections[active.active_section] = 1
  else
    active.mode = "overview"
  end
  render(active)
end

local function leave_for(active, action)
  close(active)
  action()
end

-- The picker replaces Home, scoped to the open section or the whole vault.
local function find_in_section(active, action)
  local category = active.mode ~= "overview" and active.mode or nil
  local cfg = active.cfg
  leave_for(active, function()
    picker[action](cfg, category)
  end)
end

local function set_mappings(active)
  local options = { buffer = active.view.buffer, silent = true, nowait = true }
  local function map(lhs, callback, description)
    vim.keymap.set(
      "n",
      lhs,
      callback,
      vim.tbl_extend("force", options, { desc = "Obsidian PARA Home: " .. description })
    )
  end
  map("j", function()
    move(active, 1)
  end, "next note")
  map("<Down>", function()
    move(active, 1)
  end, "next note")
  map("k", function()
    move(active, -1)
  end, "previous note")
  map("<Up>", function()
    move(active, -1)
  end, "previous note")
  map("<Tab>", function()
    switch_section(active, 1)
  end, "next section")
  map("<S-Tab>", function()
    switch_section(active, -1)
  end, "previous section")
  for key, category in pairs({ p = "projects", a = "areas", r = "resources", x = "archives" }) do
    map(key, function()
      enter_section(active, category)
    end, "open " .. category)
  end
  map("<CR>", function()
    open_selected(active)
  end, "open selected note")
  map("/", function()
    filter(active)
  end, "filter current section")
  map("f", function()
    find_in_section(active, "files")
  end, "find notes by name")
  map("g", function()
    find_in_section(active, "grep")
  end, "search note contents")
  map("<Esc>", function()
    escape(active)
  end, "clear filter or return to overview")
  map("R", function()
    refresh(active)
  end, "refresh")
  map("n", function()
    leave_for(active, function()
      require("obsidian-para-flow.inbox").new()
    end)
  end, "new Inbox note")
  map("i", function()
    leave_for(active, function()
      require("obsidian-para-flow.review").start()
    end)
  end, "review Inbox")
  map("?", function()
    vim.notify(
      "Home: j/k move, Tab section, p/a/r/x full list, / filter, f find, g grep, Enter open, n new, i review, R refresh, q close",
      vim.log.levels.INFO
    )
  end, "show help")
  map("q", function()
    close(active)
  end, "close")
end

function M.start()
  if current and current.view:is_valid() then
    current.view:focus()
    return
  end
  if current then
    current.view:close()
    current = nil
  end
  local cfg = config.get()
  local active = {
    cfg = cfg,
    vault = cfg.vault,
    mode = "overview",
    active_section = last_state.active_section,
    selections = vim.deepcopy(last_state.selections),
    filter = "",
    filtering = false,
    preview_limit = cfg.home.preview_limit,
    generation = 0,
    sections = {},
  }
  active.view = home_ui.open({
    background = cfg.home.background,
    on_redraw = function()
      render(active)
    end,
  })
  current = active
  set_mappings(active)
  refresh(active)
end

function M._current()
  return current
end

function M._set_getchar(value)
  getchar = value or vim.fn.getcharstr
end

function M._reset()
  if current then
    close(current)
  end
  current = nil
  getchar = vim.fn.getcharstr
  vault._reset()
  last_state = {
    active_section = "projects",
    selections = { inbox = 1, projects = 1, areas = 1, resources = 1, archives = 1 },
  }
end

return M
