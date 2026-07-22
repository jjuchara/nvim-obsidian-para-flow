local cli = require("obsidian-para-flow.cli")
local model = require("obsidian-para-flow.home_model")

local M = {}
local concurrency = 6

local function folder_for(cfg, category)
  return category == "inbox" and cfg.inbox.folder or cfg.para[category].folder
end

local function safe_path(path, folder)
  local prefix = folder:gsub("/+$", "") .. "/"
  return type(path) == "string"
    and path:sub(1, #prefix) == prefix
    and path:match("%.[mM][dD]$") ~= nil
    and not path:find("\\", 1, true)
    and not path:find("/%.%./", 1, true)
end

function M.load_section(cfg, category, callback)
  local folder = folder_for(cfg, category)
  cli.list_files(cfg.vault, folder, function(list_result)
    if not list_result.ok then
      callback(list_result)
      return
    end

    for _, path in ipairs(list_result.data) do
      if not safe_path(path, folder) then
        callback({
          ok = false,
          kind = "path",
          message = ("Obsidian CLI returned an unsafe %s path: %s"):format(category, path),
        })
        return
      end
    end

    if #list_result.data == 0 then
      callback({ ok = true, data = model.build(category, {}, cfg) })
      return
    end

    local next_index = 1
    local running = 0
    local finished = 0
    local items = {}
    local complete = false

    local function fail(result)
      if not complete then
        complete = true
        callback(result)
      end
    end

    local pump
    local function finish_one()
      running = running - 1
      finished = finished + 1
      if complete then
        return
      end
      if finished == #list_result.data then
        complete = true
        callback({ ok = true, data = model.build(category, items, cfg) })
        return
      end
      pump()
    end

    local function load_path(path)
      cli.properties(cfg.vault, path, function(properties_result)
        if complete then
          return
        end
        if not properties_result.ok then
          fail(properties_result)
          return
        end
        cli.file_info(cfg.vault, path, function(file_result)
          if complete then
            return
          end
          if not file_result.ok then
            fail(file_result)
            return
          end
          table.insert(items, {
            path = path,
            properties = properties_result.data,
            info = {
              created = file_result.data.created / 1000,
              modified = (file_result.data.modified or file_result.data.created) / 1000,
              size = file_result.data.size,
            },
          })
          finish_one()
        end)
      end)
    end

    pump = function()
      while not complete and running < concurrency and next_index <= #list_result.data do
        local path = list_result.data[next_index]
        next_index = next_index + 1
        running = running + 1
        load_path(path)
      end
    end
    pump()
  end)
end

function M.load_all(cfg, callback)
  for _, category in ipairs({ "inbox", "projects", "areas", "resources", "archives" }) do
    M.load_section(cfg, category, function(result)
      callback(category, result)
    end)
  end
end

return M
