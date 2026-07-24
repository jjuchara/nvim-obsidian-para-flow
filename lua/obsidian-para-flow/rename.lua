local cli = require("obsidian-para-flow.cli")
local ui = require("obsidian-para-flow.ui")

local M = {}
local pending = false

local function normalize_name(value)
  if type(value) ~= "string" then
    return nil, "Note name must be a string"
  end
  local name = vim.trim(value):gsub("%.[mM][dD]$", "")
  if name == "" or name == "." or name == ".." then
    return nil, "Note name cannot be empty, `.` or `..`"
  end
  if name:find("/", 1, true) or name:find("\\", 1, true) then
    return nil, "Note name cannot contain path separators"
  end
  if name:find("%z") or name:find("[%c]") then
    return nil, "Note name cannot contain control characters"
  end
  return name
end

local function destination_for(path, name)
  local folder = path:match("^(.*)/[^/]+$")
  return (folder and (folder .. "/") or "") .. name .. ".md"
end

local function buffers_for(root, path)
  local expected = vim.uv.fs_realpath(vim.fs.joinpath(root, path))
    or vim.fs.normalize(vim.fs.joinpath(root, path))
  local buffers = {}
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    local buffer_path = vim.api.nvim_buf_get_name(buffer)
    local normalized = buffer_path ~= ""
        and (vim.uv.fs_realpath(buffer_path) or vim.fs.normalize(buffer_path))
      or nil
    if vim.api.nvim_buf_is_loaded(buffer) and normalized == expected then
      table.insert(buffers, buffer)
    end
  end
  return buffers
end

local function complete(callback, result)
  pending = false
  if callback then
    callback(result)
  end
end

function M.start(cfg, path, options, callback)
  options = options or {}
  if pending then
    ui.notify_error("A note rename is already in progress")
    return false
  end
  if type(path) ~= "string" or path == "" or not options.vault_root then
    ui.notify_error("Could not determine the selected vault note")
    return false
  end
  local source_buffers = buffers_for(options.vault_root, path)
  for _, buffer in ipairs(source_buffers) do
    if vim.bo[buffer].modified then
      ui.notify_error("Save or discard the modified Neovim buffer before renaming: " .. path)
      return false
    end
  end

  pending = true
  local current_name = vim.fs.basename(path):gsub("%.[mM][dD]$", "")
  ui.input({ prompt = "Rename note: ", default = current_name }, function(value)
    if value == nil then
      complete(callback, { status = "canceled" })
      return
    end
    local name, name_error = normalize_name(value)
    if not name then
      ui.notify_error(name_error)
      complete(callback, { status = "error", message = name_error })
      return
    end
    local destination = destination_for(path, name)
    if destination == path then
      complete(callback, { status = "unchanged", path = path })
      return
    end
    local full_destination = vim.fs.joinpath(options.vault_root, destination)
    if vim.uv.fs_stat(full_destination) then
      local message = "A note already exists at " .. destination
      ui.notify_error(message)
      complete(callback, { status = "conflict", message = message })
      return
    end
    cli.rename(cfg.vault, path, name, function(result)
      if not result.ok then
        ui.notify_error(result.message or ("Could not rename " .. path))
        complete(callback, {
          status = "error",
          message = result.message,
          path = path,
        })
        return
      end
      vim.notify(
        ("obsidian-para-flow: renamed %s to %s"):format(path, destination),
        vim.log.levels.INFO
      )
      for _, buffer in ipairs(source_buffers) do
        if vim.api.nvim_buf_is_valid(buffer) then
          pcall(vim.api.nvim_buf_set_name, buffer, full_destination)
        end
      end
      complete(callback, {
        status = "renamed",
        path = destination,
        previous_path = path,
      })
    end)
  end)
  return true
end

function M._normalize_name(value)
  return normalize_name(value)
end

function M._reset()
  pending = false
end

return M
