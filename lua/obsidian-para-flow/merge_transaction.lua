local cli = require("obsidian-para-flow.cli")

local M = {}

function M.execute(vault, options, callback)
  local sources = options.sources or { options.source }
  local trashed = {}

  local function source_states(failed_source)
    local states = {}
    local trashed_lookup = {}
    for _, path in ipairs(trashed) do
      trashed_lookup[path] = true
    end
    for _, path in ipairs(sources) do
      local status = trashed_lookup[path] and "trashed" or "not attempted"
      if path == failed_source then
        status = "trash failed"
      end
      table.insert(states, { path = path, status = status })
    end
    return states
  end

  local function restore(failure, failed_source)
    cli.write(vault, options.target, options.target_snapshot, function(restore_result)
      if restore_result.ok and #trashed == 0 then
        callback({
          ok = false,
          kind = "rolled_back",
          message = failure.message,
          target = options.target,
          source = sources[1],
          sources = sources,
        })
      else
        callback({
          ok = false,
          kind = "rollback",
          message = failure.message,
          recovery = {
            target = options.target,
            source = sources[1],
            sources = source_states(failed_source),
            target_state = restore_result.ok and "restored from the pre-merge snapshot"
              or "merge result or partial write may remain",
            source_state = #trashed == 0 and "Merge source was not confirmed as trashed"
              or "One or more merge sources are already in the Obsidian trash",
            rollback_failure = restore_result.ok and nil or restore_result.message,
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
    local function trash_next(index)
      local source = sources[index]
      if not source then
        callback({
          ok = true,
          target = options.target,
          source = sources[1],
          sources = sources,
        })
        return
      end
      cli.trash(vault, source, function(trash_result)
        if not trash_result.ok then
          restore(trash_result, source)
          return
        end
        table.insert(trashed, source)
        trash_next(index + 1)
      end)
    end
    trash_next(1)
  end)
end

return M
