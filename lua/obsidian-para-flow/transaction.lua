local cli = require("obsidian-para-flow.cli")

local M = {}

local function run_step(vault, path, step, callback)
  if step.action == "remove" then
    cli.property_remove(vault, path, step.name, callback)
  else
    cli.property_set(vault, path, step.name, step.value, step.type, callback)
  end
end

local function recovery_details(plan, applied, rollback_failures, failure)
  local changed = {}
  for _, index in ipairs(applied) do
    table.insert(changed, plan.apply[index].name)
  end
  return {
    source = plan.move.path,
    destination = plan.move.destination,
    failure = failure.message,
    changed_properties = changed,
    rollback_failures = rollback_failures,
  }
end

function M.execute(vault, plan, callback)
  local applied = {}

  local function rollback(failure)
    local rollback_failures = {}
    local index = #applied
    local function next_compensation()
      if index == 0 then
        callback({
          ok = false,
          kind = #rollback_failures == 0 and "rolled_back" or "rollback",
          message = failure.message,
          recovery = recovery_details(plan, applied, rollback_failures, failure),
        })
        return
      end

      local apply_index = applied[index]
      local step = plan.compensate[#plan.apply - apply_index + 1]
      run_step(vault, plan.move.path, step, function(result)
        if not result.ok then
          table.insert(rollback_failures, {
            property = step.name,
            action = step.action,
            message = result.message,
          })
        end
        index = index - 1
        next_compensation()
      end)
    end
    next_compensation()
  end

  local index = 1
  local function apply_next()
    local step = plan.apply[index]
    if not step then
      cli.move(vault, plan.move.path, plan.move.destination, function(result)
        if result.ok then
          callback({ ok = true, destination = plan.move.destination })
        else
          rollback(result)
        end
      end)
      return
    end

    run_step(vault, plan.move.path, {
      action = "set",
      name = step.name,
      value = step.value,
      type = step.type,
    }, function(result)
      if not result.ok then
        rollback(result)
        return
      end
      table.insert(applied, index)
      index = index + 1
      apply_next()
    end)
  end

  apply_next()
end

return M
