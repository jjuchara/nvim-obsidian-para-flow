local cli = require("obsidian-para-flow.cli")
local ui = require("obsidian-para-flow.ui")

local M = {}

local function canceled(callback)
  callback({ ok = false, kind = "canceled" })
end

local function folder_options(root, folders)
  local prefix = root:gsub("/+$", "") .. "/"
  local result = { root }
  local seen = { [root] = true }
  table.sort(folders)
  for _, folder in ipairs(folders) do
    if folder:sub(1, #prefix) == prefix and not seen[folder] then
      seen[folder] = true
      table.insert(result, folder)
    end
  end
  return result
end

local function area_link(path)
  return "[[" .. path:gsub("%.md$", "") .. "]]"
end

local function collect_area(vault, callback)
  cli.search(vault, "tag:#area", function(result)
    if not result.ok then
      callback(result)
      return
    end
    local paths = {}
    for _, path in ipairs(result.data) do
      if path:match("%.md$") and not path:find("\\", 1, true) and not path:find("..", 1, true) then
        table.insert(paths, path)
      end
    end
    table.sort(paths)
    if #paths == 0 then
      callback({ ok = false, kind = "input", message = "No #area notes were found" })
      return
    end
    ui.select(paths, { prompt = "Select area note:" }, function(choice)
      if not choice then
        canceled(callback)
        return
      end
      callback({ ok = true, area = area_link(choice) })
    end)
  end)
end

local function collect_archive_reason(callback)
  ui.input({ prompt = "Archive reason: " }, function(value)
    if value == nil then
      canceled(callback)
      return
    end
    value = vim.trim(value)
    if value == "" then
      callback({ ok = false, kind = "input", message = "Archive reason cannot be empty" })
      return
    end
    callback({ ok = true, archive_reason = value })
  end)
end

local function contains_path(paths, target)
  target = target:lower()
  for _, path in ipairs(paths) do
    if path:lower() == target then
      return true
    end
  end
  return false
end

local function preflight(cfg, note, category, folder, context, callback)
  local filename = note.path:match("([^/]+)$")
  local destination = folder:gsub("/+$", "") .. "/" .. filename
  cli.file_info(cfg.vault, note.path, function(source_result)
    if not source_result.ok then
      callback(source_result)
      return
    end
    cli.folder_info(cfg.vault, folder, function(folder_result)
      if not folder_result.ok then
        callback(folder_result)
        return
      end
      cli.list_files(cfg.vault, folder, function(files_result)
        if not files_result.ok then
          callback(files_result)
          return
        end
        if contains_path(files_result.data, destination) then
          callback({
            ok = false,
            kind = "conflict",
            message = ("Destination note already exists: %s"):format(destination),
            destination = destination,
          })
          return
        end
        callback({
          ok = true,
          category = category,
          destination = destination,
          context = context,
        })
      end)
    end)
  end)
end

function M.prepare(cfg, note, category, callback)
  local root = cfg.para[category].folder
  cli.list_folders(cfg.vault, root, function(result)
    if not result.ok then
      callback(result)
      return
    end
    ui.select(folder_options(root, result.data), {
      prompt = ("Select %s folder:"):format(category),
    }, function(folder)
      if not folder then
        canceled(callback)
        return
      end

      local context = {
        created = os.date("%Y-%m-%dT%H:%M:%S", note.file_created),
        archived = os.date("%Y-%m-%d"),
      }
      local needs_area = (category == "projects" or category == "resources")
        and (note.properties.area == nil or vim.trim(tostring(note.properties.area)) == "")
      local needs_reason = category == "archives"
        and (
          note.properties.archive_reason == nil
          or vim.trim(tostring(note.properties.archive_reason)) == ""
        )

      local function finish()
        preflight(cfg, note, category, folder, context, callback)
      end
      local function archive_prompt()
        if not needs_reason then
          finish()
          return
        end
        collect_archive_reason(function(reason_result)
          if not reason_result.ok then
            callback(reason_result)
            return
          end
          context.archive_reason = reason_result.archive_reason
          finish()
        end)
      end
      if needs_area then
        collect_area(cfg.vault, function(area_result)
          if not area_result.ok then
            callback(area_result)
            return
          end
          context.area = area_result.area
          archive_prompt()
        end)
      else
        archive_prompt()
      end
    end)
  end)
end

function M._folder_options(root, folders)
  return folder_options(root, folders)
end

return M
