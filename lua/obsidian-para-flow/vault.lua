local cli = require("obsidian-para-flow.cli")

local M = {}
local cache = {}

-- Resolves the absolute vault root through the Obsidian CLI and caches it, so
-- mappings outside Home do not pay for a CLI round trip on every invocation.
-- Pass `refresh` to bypass the cache, as Home does on an explicit reload.
function M.root(cfg, callback, options)
  local vault = cfg.vault
  if cache[vault] and not (options or {}).refresh then
    callback({ ok = true, root = cache[vault] })
    return
  end
  cli.vault_info(vault, "path", function(result)
    if not result.ok or result.stdout == "" then
      cache[vault] = nil
      callback({
        ok = false,
        message = result.message or "Obsidian CLI returned an empty vault path",
      })
      return
    end
    cache[vault] = result.stdout
    callback({ ok = true, root = result.stdout })
  end)
end

-- `category` is a PARA category, "inbox", or nil for the whole vault.
function M.folder(cfg, category, callback, options)
  M.root(cfg, function(result)
    if not result.ok or not category then
      callback(result)
      return
    end
    local folder = category == "inbox" and cfg.inbox.folder or cfg.para[category].folder
    callback({ ok = true, root = vim.fs.joinpath(result.root, folder) })
  end, options)
end

function M._reset()
  cache = {}
end

return M
