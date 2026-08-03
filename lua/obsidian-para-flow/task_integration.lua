local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local date = require("obsidian-para-flow.date")
local ui = require("obsidian-para-flow.ui")

local M = {}
local marker = "<!-- obsidian-para-flow:expire-on-complete -->"
local unsubscribe
local registered_tasks

local function safe_note_path(path)
  return type(path) == "string"
    and path ~= ""
    and not vim.startswith(path, "/")
    and not path:find("\\", 1, true)
    and not path:match("^%.%.[/\\]")
    and not path:match("[/\\]%.%.[/\\]")
    and path:lower():match("%.md$") ~= nil
end

local function inside(path, folder)
  folder = folder:gsub("/+$", "")
  return path == folder or vim.startswith(path, folder .. "/")
end

local function has_value(value)
  return value ~= nil and value ~= vim.NIL and (type(value) ~= "string" or vim.trim(value) ~= "")
end

function M.description_suffix(path, include_link, expire_on_complete)
  local parts = {}
  if include_link then
    parts[#parts + 1] = "[[" .. path:gsub("%.md$", "") .. "]]"
  end
  if include_link and expire_on_complete then
    parts[#parts + 1] = marker
  end
  return #parts > 0 and table.concat(parts, " ") or nil
end

function M.linked_path(text)
  if type(text) ~= "string" then
    return nil
  end
  local before_marker = text:match("^(.-)%s*" .. vim.pesc(marker))
  if not before_marker then
    return nil
  end
  local target = before_marker:match("%[%[([^%[%]]+)%]%]%s*$")
  if not target then
    return nil
  end
  target = target:match("^([^|#]+)")
  if not target or target == "" then
    return nil
  end
  local path = target:lower():match("%.md$") and target or (target .. ".md")
  return safe_note_path(path) and path or nil
end

function M.handle_toggle(event)
  if type(event) ~= "table" or event.done ~= true or type(event.task) ~= "table" then
    return
  end
  local ok, cfg = pcall(config.get)
  if not ok or not cfg.todo.expire_created_note then
    return
  end
  local path = M.linked_path(event.task.text or event.task.raw)
  if
    not path
    or inside(path, cfg.para.projects.folder)
    or inside(path, cfg.para.archives.folder)
  then
    return
  end

  cli.ensure_vault(cfg.vault, function(vault_result)
    if not vault_result.ok then
      ui.notify_error(vault_result.message or "Could not verify the linked note vault")
      return
    end
    cli.properties(cfg.vault, path, function(properties_result)
      if not properties_result.ok then
        ui.notify_error(properties_result.message or "Could not read the linked note")
        return
      end
      if has_value(properties_result.data.expired_at) then
        return
      end
      cli.property_set(cfg.vault, path, "expired_at", date.today(), "date", function(result)
        if not result.ok then
          ui.notify_error(result.message or "Could not set expired_at on the linked note")
          return
        end
        vim.notify(("obsidian-para-flow: set expired_at for linked note `%s`"):format(path))
      end)
    end)
  end)
end

function M.register(tasks)
  if tasks == nil then
    local ok, loaded = pcall(require, "obsidian-tasks")
    if not ok then
      return false
    end
    tasks = loaded
  end
  if type(tasks) ~= "table" or type(tasks.on_toggle) ~= "function" then
    return false
  end
  if registered_tasks == tasks and unsubscribe then
    return true
  end
  if unsubscribe then
    pcall(unsubscribe)
  end
  local ok, result = pcall(tasks.on_toggle, M.handle_toggle)
  if not ok or type(result) ~= "function" then
    unsubscribe = nil
    registered_tasks = nil
    return false
  end
  unsubscribe = result
  registered_tasks = tasks
  return true
end

function M._reset()
  if unsubscribe then
    pcall(unsubscribe)
  end
  unsubscribe = nil
  registered_tasks = nil
end

return M
