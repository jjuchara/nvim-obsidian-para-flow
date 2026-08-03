local cli = require("obsidian-para-flow.cli")
local metadata = require("obsidian-para-flow.metadata")

local M = {}
local concurrency = 6

local function inside(path, folder)
  folder = folder:gsub("/+$", "")
  return path == folder or vim.startswith(path, folder .. "/")
end

local function safe_path(path)
  return type(path) == "string"
    and path ~= ""
    and not vim.startswith(path, "/")
    and not path:find("\\", 1, true)
    and not path:match("^%.%.[/\\]")
    and not path:match("[/\\]%.%.[/\\]")
    and path:lower():match("%.md$") ~= nil
end

local function today_timestamp()
  local now = os.date("*t")
  return os.time({ year = now.year, month = now.month, day = now.day, hour = 0, min = 0, sec = 0 })
end

local function has_expiration_value(value)
  return value ~= nil and value ~= vim.NIL and (type(value) ~= "string" or vim.trim(value) ~= "")
end

function M.load(cfg, callback)
  cli.ensure_vault(cfg.vault, function(vault_result)
    if not vault_result.ok then
      callback(vault_result)
      return
    end
    cli.list_files(cfg.vault, nil, function(files_result)
      if not files_result.ok then
        callback(files_result)
        return
      end
      local paths = {}
      for _, path in ipairs(files_result.data) do
        if not safe_path(path) then
          callback({
            ok = false,
            kind = "path",
            message = "Obsidian CLI returned an unsafe path: " .. tostring(path),
          })
          return
        end
        if not inside(path, cfg.para.archives.folder) then
          table.insert(paths, path)
        end
      end
      if #paths == 0 then
        callback({ ok = true, data = {}, invalid = {} })
        return
      end

      local candidates, invalid = {}, {}
      local next_index, running, finished = 1, 0, 0
      local done = false
      local cutoff = today_timestamp()
      local pump
      local function finish_one()
        running = running - 1
        finished = finished + 1
        if done then
          return
        end
        if finished == #paths then
          done = true
          table.sort(candidates, function(left, right)
            return left.expires == right.expires and left.path < right.path
              or left.expires < right.expires
          end)
          table.sort(invalid)
          callback({ ok = true, data = candidates, invalid = invalid })
          return
        end
        pump()
      end
      local function load_path(path)
        cli.properties(cfg.vault, path, function(properties_result)
          if done then
            return
          end
          if not properties_result.ok then
            done = true
            callback(properties_result)
            return
          end
          local is_project = inside(path, cfg.para.projects.folder)
          local property = is_project and "deadline" or "expired_at"
          local raw = properties_result.data[property]
          if has_expiration_value(raw) then
            local expires = metadata.parse_date(tostring(raw))
            if not expires then
              table.insert(invalid, path .. ": invalid " .. property)
            elseif expires < cutoff or (property == "expired_at" and expires == cutoff) then
              cli.file_info(cfg.vault, path, function(file_result)
                if done then
                  return
                end
                if not file_result.ok then
                  done = true
                  callback(file_result)
                  return
                end
                table.insert(candidates, {
                  path = path,
                  properties = properties_result.data,
                  file_created = file_result.data.created / 1000,
                  expires = expires,
                  expiration_property = property,
                  project = is_project,
                })
                finish_one()
              end)
              return
            end
          end
          finish_one()
        end)
      end
      pump = function()
        while not done and running < concurrency and next_index <= #paths do
          local path = paths[next_index]
          next_index = next_index + 1
          running = running + 1
          load_path(path)
        end
      end
      pump()
    end)
  end)
end

function M._inside(path, folder)
  return inside(path, folder)
end
function M._safe_path(path)
  return safe_path(path)
end
function M._has_expiration_value(value)
  return has_expiration_value(value)
end

return M
