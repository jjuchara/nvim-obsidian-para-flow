local home_ui = require("obsidian-para-flow.home_ui")

local T = MiniTest.new_set()

local function ready(category, items)
  return {
    status = "ready",
    data = {
      category = category,
      items = items or {},
      groups = items and { { name = "Group", items = items } } or {},
    },
  }
end

local function state()
  local project = {
    category = "projects",
    name = "Home project",
    path = "1. Projects/Home project.md",
    group = "В работе",
    properties = { status = "В работе", area = "[[Work]]" },
    info = { created = 1, modified = 2 },
  }
  return {
    vault = "Test Vault",
    mode = "overview",
    active_section = "projects",
    preview_limit = 5,
    selections = { inbox = 1, projects = 1, areas = 1, resources = 1, archives = 1 },
    filter = "",
    sections = {
      inbox = ready("inbox"),
      projects = ready("projects", { project }),
      areas = { status = "loading" },
      resources = { status = "error", message = "Unavailable" },
      archives = ready("archives"),
    },
  }
end

T["opens a dedicated Home tab, renders states, and restores the origin"] = function()
  local origin = vim.api.nvim_get_current_win()
  local tabs = #vim.api.nvim_list_tabpages()
  local columns = vim.o.columns
  local lines = vim.o.lines
  vim.o.columns = 140
  vim.o.lines = 40
  local view = home_ui.open({
    background = { provider = "constellation", intensity = 0.12 },
  })
  local value = state()
  view:render(value)
  local content = table.concat(vim.api.nvim_buf_get_lines(view.buffer, 0, -1, false), "\n")
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs + 1)
  MiniTest.expect.equality(content:find("PARA HOME", 1, true) ~= nil, true)
  MiniTest.expect.equality(content:find("Home project", 1, true) ~= nil, true)
  MiniTest.expect.equality(content:find("Unavailable", 1, true) ~= nil, true)
  MiniTest.expect.no_equality(vim.api.nvim_get_hl(0, { name = "ObsidianParaHomeAccent" }).fg, nil)

  value.mode = "projects"
  view:render(value)
  content = table.concat(vim.api.nvim_buf_get_lines(view.buffer, 0, -1, false), "\n")
  MiniTest.expect.equality(content:find("DETAILS", 1, true) ~= nil, vim.o.columns >= 100)
  MiniTest.expect.equality(content:find("Path: 1. Projects/Home project.md", 1, true) ~= nil, true)

  view:close()
  vim.o.columns = columns
  vim.o.lines = lines
  MiniTest.expect.equality(#vim.api.nvim_list_tabpages(), tabs)
  MiniTest.expect.equality(vim.api.nvim_get_current_win(), origin)
end

return T
