local M = {}

local defaults = {
  mappings = {
    new = "<leader>on",
    review = "<leader>oi",
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
  validate_mapping(options.mappings.review, "mappings.review")

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
