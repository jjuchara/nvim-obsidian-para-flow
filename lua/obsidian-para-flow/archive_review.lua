local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local date = require("obsidian-para-flow.date")
local date_picker = require("obsidian-para-flow.date_picker")
local loader = require("obsidian-para-flow.archive_loader")
local metadata = require("obsidian-para-flow.metadata")
local sorting = require("obsidian-para-flow.sorting")
local transaction = require("obsidian-para-flow.transaction")
local trash = require("obsidian-para-flow.trash")
local ui = require("obsidian-para-flow.ui")

local M = {}
local active

local function format_candidate(note)
  return ("%s  %s  %s"):format(
    os.date("%Y-%m-%d", note.expires),
    note.expiration_property,
    note.path
  )
end

local function remove_current(note)
  if not active then
    return
  end
  active.notes = vim.tbl_filter(function(candidate)
    return candidate.path ~= note.path
  end, active.notes)
end

local function show_queue() end

local function stay()
  vim.schedule(show_queue)
end

local function finish(note, message)
  remove_current(note)
  if message then
    vim.notify("obsidian-para-flow: " .. message)
  end
  vim.schedule(show_queue)
end

local function change_date(note)
  local cfg = config.get()
  date_picker.pick({
    picker = cfg.archive_review.date_picker,
    title = ("New %s"):format(note.expiration_property),
    prompt = ("New %s (YYYY-MM-DD or DD.MM.YYYY): "):format(note.expiration_property),
    initial = date.today(),
  }, function(result)
    if result.action ~= "select" then
      stay()
      return
    end
    local normalized = metadata.normalize_date(result.value)
    local timestamp = normalized and metadata.parse_date(normalized) or nil
    if not timestamp then
      ui.notify_error("Expected a valid date in YYYY-MM-DD or DD.MM.YYYY format")
      stay()
      return
    end
    local now = os.date("*t")
    local today =
      os.time({ year = now.year, month = now.month, day = now.day, hour = 0, min = 0, sec = 0 })
    if timestamp < today then
      ui.notify_error("The new expiration date must be today or later")
      stay()
      return
    end
    cli.properties(cfg.vault, note.path, function(properties_result)
      if not properties_result.ok then
        ui.notify_error(properties_result.message)
        stay()
        return
      end
      if not vim.deep_equal(properties_result.data, note.properties) then
        ui.notify_error(
          "The note metadata changed after the archive review started; refresh and try again"
        )
        active = nil
        return
      end
      cli.property_set(
        cfg.vault,
        note.path,
        note.expiration_property,
        normalized,
        "date",
        function(property_result)
          if not property_result.ok then
            ui.notify_error(property_result.message or "Could not update the expiration date")
            stay()
            return
          end
          finish(note, ("updated %s for `%s`"):format(note.expiration_property, note.path))
        end
      )
    end)
  end)
end

local function execute_archive(note, status)
  local cfg = config.get()
  sorting.prepare(cfg, note, "archives", function(prepared)
    if not prepared.ok then
      if prepared.kind ~= "canceled" then
        ui.notify_error(prepared.message)
      end
      stay()
      return
    end
    cli.properties(cfg.vault, note.path, function(properties_result)
      if not properties_result.ok then
        ui.notify_error(properties_result.message)
        stay()
        return
      end
      prepared.context.replacements = note.project
          and {
            status = { value = status, type = "text" },
          }
        or nil
      local plan, error_message = metadata.operation_plan(
        note.path,
        prepared.destination,
        "archives",
        properties_result.data,
        prepared.context,
        cfg.para
      )
      if not plan or #plan.preflight.missing > 0 then
        ui.notify_error(
          error_message
            or ("Missing required metadata: " .. table.concat(plan.preflight.missing, ", "))
        )
        stay()
        return
      end
      transaction.execute(cfg.vault, plan, function(result)
        if not result.ok then
          if result.kind == "rollback" then
            local failures = vim.tbl_map(function(failure)
              return ("%s (%s): %s"):format(failure.property, failure.action, failure.message)
            end, result.recovery.rollback_failures)
            ui.notify_error(
              (
                "Archive transaction requires manual recovery for `%s`. "
                .. "Original failure: %s. Rollback failures: %s"
              ):format(
                result.recovery.source,
                result.recovery.failure,
                table.concat(failures, "; ")
              )
            )
            active = nil
            return
          end
          ui.notify_error(result.message or "Archive transaction failed and was rolled back")
          stay()
          return
        end
        finish(
          note,
          status and ("archived `%s` with status `%s`"):format(note.path, status)
            or ("archived `%s`"):format(note.path)
        )
      end)
    end)
  end)
end

local function archive(note)
  if not note.project then
    execute_archive(note)
    return
  end
  ui.select(config.get().archive_review.project_statuses, {
    prompt = "Project status after archiving:",
  }, function(status)
    if status then
      execute_archive(note, status)
    else
      stay()
    end
  end)
end

local function move_to_trash(note)
  trash.confirm(config.get(), note.path, function(result)
    if result.status == "deleted" then
      finish(note)
    else
      stay()
    end
  end)
end

show_queue = function()
  if not active then
    return
  end
  if #active.notes == 0 then
    vim.notify("obsidian-para-flow: expired-note review is complete")
    active = nil
    return
  end
  local title = ("Expired notes (%d)"):format(#active.notes)
  ui.action_list(active.notes, {
    title = title,
    footer = "[r] Reschedule  [a] Archive  [d] Trash  [s] Skip  [q] Close",
    vertical_padding = 1,
    actions = {
      { key = "r", value = "reschedule" },
      { key = "a", value = "archive" },
      { key = "d", value = "trash" },
      { key = "s", value = "skip" },
    },
    format_item = format_candidate,
  }, function(action, note)
    if action == "reschedule" then
      change_date(note)
    elseif action == "archive" then
      archive(note)
    elseif action == "trash" then
      move_to_trash(note)
    elseif action == "skip" then
      finish(note)
    else
      active = nil
    end
  end)
end

function M.start()
  if active then
    ui.notify_error("An expired-note review is already active")
    return
  end
  local cfg = config.get()
  loader.load(cfg, function(result)
    if not result.ok then
      ui.notify_error(result.message)
      return
    end
    if #result.invalid > 0 then
      vim.notify(
        "obsidian-para-flow: skipped invalid expiration metadata:\n"
          .. table.concat(result.invalid, "\n"),
        vim.log.levels.WARN
      )
    end
    active = { notes = result.data }
    show_queue()
  end)
end

function M._reset()
  active = nil
end
function M._current()
  return active
end

return M
