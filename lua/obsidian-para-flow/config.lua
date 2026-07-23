local M = {}

local defaults = {
  mappings = {
    home = "<leader>oh",
    new = "<leader>on",
    new_with_task = false,
    capture = "<leader>ot",
    review = "<leader>oi",
    find = "<leader>of",
  },
  capture = {
    profiles = {},
  },
  search = {
    provider = "auto",
  },
  home = {
    preview_limit = 5,
    projects = {
      status_order = { "В работе", "Планируется" },
    },
    background = {
      provider = "constellation",
      intensity = 0.12,
    },
  },
  review = {
    layout = "float",
    width = 0.7,
    height = 0.7,
    winblend = 0,
  },
}

local current

local function fail(path, message)
  error(("obsidian-para-flow: invalid config `%s`: %s"):format(path, message), 0)
end

local function require_table(value, path)
  if type(value) ~= "table" then
    fail(path, "expected a table")
  end
end

local function require_string(value, path)
  if type(value) ~= "string" or vim.trim(value) == "" then
    fail(path, "expected a non-empty string")
  end
end

local function require_vault_path(value, path)
  require_string(value, path)
  if value:sub(1, 1) == "/" or value:find("\\", 1, true) then
    fail(path, "expected a vault-relative path using `/`")
  end
  for part in value:gmatch("[^/]+") do
    if part == "." or part == ".." then
      fail(path, "`.` and `..` segments are not allowed")
    end
  end
end

local function validate_mapping(value, path)
  if value ~= false and (type(value) ~= "string" or vim.trim(value) == "") then
    fail(path, "expected a non-empty string or false")
  end
end

local function validate_size(value, path)
  if type(value) ~= "number" or value <= 0 then
    fail(path, "expected a positive number")
  end
  if value < 1 then
    return
  end
  if value % 1 ~= 0 then
    fail(path, "values at least 1 must be whole columns or rows")
  end
end

local function validate_winblend(value)
  if type(value) ~= "number" or value % 1 ~= 0 or value < 0 or value > 100 then
    fail("review.winblend", "expected a whole number from 0 to 100")
  end
end

local function validate_home(options)
  if
    type(options.preview_limit) ~= "number"
    or options.preview_limit % 1 ~= 0
    or options.preview_limit < 1
  then
    fail("home.preview_limit", "expected a positive whole number")
  end

  require_table(options.projects, "home.projects")
  require_table(options.projects.status_order, "home.projects.status_order")
  for index, value in ipairs(options.projects.status_order) do
    require_string(value, ("home.projects.status_order[%d]"):format(index))
  end

  require_table(options.background, "home.background")
  local provider = options.background.provider
  if provider ~= false and provider ~= "constellation" and type(provider) ~= "function" then
    fail("home.background.provider", "expected `constellation`, false, or a function")
  end
  local intensity = options.background.intensity
  if type(intensity) ~= "number" or intensity < 0 or intensity > 1 then
    fail("home.background.intensity", "expected a number from 0 to 1")
  end
end

local function validate_capture(options)
  require_table(options, "capture")
  require_table(options.profiles, "capture.profiles")
  for name, profile in pairs(options.profiles) do
    require_string(name, "capture.profiles key")
    if not name:match("^[%w_-]+$") then
      fail("capture.profiles key", "expected letters, digits, `_`, or `-`")
    end
    require_table(profile, "capture.profiles." .. name)
    require_vault_path(profile.folder, "capture.profiles." .. name .. ".folder")
    require_string(profile.quickadd_choice, "capture.profiles." .. name .. ".quickadd_choice")
    if profile.label ~= nil then
      require_string(profile.label, "capture.profiles." .. name .. ".label")
    end
    if profile.prompt ~= nil then
      require_string(profile.prompt, "capture.profiles." .. name .. ".prompt")
    end
    if profile.todo ~= nil and type(profile.todo) ~= "boolean" then
      fail("capture.profiles." .. name .. ".todo", "expected a boolean")
    end
  end
end

local function validate(options)
  require_table(options, "options")
  require_string(options.vault, "vault")

  require_table(options.inbox, "inbox")
  require_vault_path(options.inbox.folder, "inbox.folder")
  require_string(options.inbox.quickadd_choice, "inbox.quickadd_choice")

  require_table(options.para, "para")
  for _, category in ipairs({ "projects", "areas", "resources", "archives" }) do
    local value = options.para[category]
    require_table(value, "para." .. category)
    require_vault_path(value.folder, "para." .. category .. ".folder")
  end
  require_string(options.para.projects.link, "para.projects.link")
  require_string(options.para.areas.link, "para.areas.link")

  validate_mapping(options.mappings.new, "mappings.new")
  validate_mapping(options.mappings.new_with_task, "mappings.new_with_task")
  validate_mapping(options.mappings.capture, "mappings.capture")
  validate_mapping(options.mappings.review, "mappings.review")
  validate_mapping(options.mappings.home, "mappings.home")
  validate_mapping(options.mappings.find, "mappings.find")

  require_table(options.search, "search")
  if
    not vim.tbl_contains(
      { "auto", "snacks", "fzf-lua", "telescope", "builtin" },
      options.search.provider
    )
  then
    fail("search.provider", "expected `auto`, `snacks`, `fzf-lua`, `telescope`, or `builtin`")
  end

  validate_home(options.home)
  validate_capture(options.capture)

  if options.review.layout ~= "float" and options.review.layout ~= "fullscreen" then
    fail("review.layout", "expected `float` or `fullscreen`")
  end
  validate_size(options.review.width, "review.width")
  validate_size(options.review.height, "review.height")
  validate_winblend(options.review.winblend)
end

function M.setup(options)
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(defaults), options or {})
  validate(merged)
  current = merged
  return vim.deepcopy(current)
end

function M.get()
  if not current then
    error("obsidian-para-flow: setup() must be called first", 0)
  end
  return current
end

function M.defaults()
  return vim.deepcopy(defaults)
end

function M._reset()
  current = nil
end

return M
