local cli = require("obsidian-para-flow.cli")

local M = {}

function M.execute(vault, options, callback)
  local function restore(failure)
    cli.write(vault, options.target, options.target_snapshot, function(restore_result)
      if restore_result.ok then
        callback({
          ok = false,
          kind = "rolled_back",
          message = failure.message,
          target = options.target,
          source = options.source,
        })
      else
        callback({
          ok = false,
          kind = "rollback",
          message = failure.message,
          recovery = {
            target = options.target,
            source = options.source,
            target_state = "merge result or partial write may remain",
            source_state = "Inbox source was not confirmed as trashed",
            rollback_failure = restore_result.message,
          },
        })
      end
    end)
  end

  cli.write(vault, options.target, options.content, function(write_result)
    if not write_result.ok then
      restore(write_result)
      return
    end
    cli.trash(vault, options.source, function(trash_result)
      if not trash_result.ok then
        restore(trash_result)
        return
      end
      callback({ ok = true, target = options.target, source = options.source })
    end)
  end)
end

return M
