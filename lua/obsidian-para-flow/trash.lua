local cli = require("obsidian-para-flow.cli")
local ui = require("obsidian-para-flow.ui")

local M = {}

local function valid_note_path(path)
  return type(path) == "string"
    and path ~= ""
    and not vim.startswith(path, "/")
    and not path:match("^%a:[/\\]")
    and not path:match("^%.%.[/\\]")
    and not path:match("[/\\]%.%.[/\\]")
    and path:lower():match("%.md$") ~= nil
end

function M.confirm(cfg, path, callback)
  if not valid_note_path(path) then
    local result = {
      status = "error",
      message = "Refusing to trash an invalid vault note path: " .. tostring(path),
    }
    ui.notify_error(result.message)
    callback(result)
    return
  end

  ui.select({ "Cancel", "Move to trash" }, {
    prompt = ("Move `%s` to the Obsidian trash?"):format(path),
  }, function(choice)
    if choice ~= "Move to trash" then
      callback({ status = "canceled", path = path })
      return
    end
    cli.trash(cfg.vault, path, function(result)
      if not result.ok then
        local message = result.message or ("Could not move `%s` to trash"):format(path)
        ui.notify_error(message)
        callback({ status = "error", path = path, message = message })
        return
      end
      vim.notify("obsidian-para-flow: moved `" .. path .. "` to the Obsidian trash")
      callback({ status = "deleted", path = path })
    end)
  end)
end

return M
