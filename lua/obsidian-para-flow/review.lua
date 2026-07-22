local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local inbox = require("obsidian-para-flow.inbox")
local metadata = require("obsidian-para-flow.metadata")
local session = require("obsidian-para-flow.session")
local sorting = require("obsidian-para-flow.sorting")
local transaction = require("obsidian-para-flow.transaction")
local ui = require("obsidian-para-flow.ui")

local M = {}
local current
local save_current
local show_current_note

local footer = {
  "p Project · a Area · r Resource · x Archive · d Delete · e Do now · s Skip · q Quit",
}

local function status_lines(snapshot)
  local position = snapshot.processed + snapshot.skipped + 1
  return {
    ("Inbox review · %d/%d · %s"):format(position, snapshot.initial, snapshot.current.path),
  }
end

local function file_fingerprint(path)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return nil
  end
  return {
    size = stat.size,
    mtime_sec = stat.mtime.sec,
    mtime_nsec = stat.mtime.nsec,
  }
end

local function open_note_buffer(vault_root, note)
  local full_path = vim.fs.joinpath(vault_root, note.path)
  local fingerprint = file_fingerprint(full_path)
  if not fingerprint then
    return nil, ("Inbox note no longer exists: %s"):format(note.path)
  end
  local buffer = vim.fn.bufadd(full_path)
  vim.fn.bufload(buffer)
  vim.bo[buffer].buflisted = true
  vim.bo[buffer].modifiable = true
  vim.bo[buffer].readonly = false
  vim.bo[buffer].filetype = "markdown"
  return {
    buffer = buffer,
    full_path = full_path,
    fingerprint = fingerprint,
  }
end

local function set_action_mappings(target)
  local options = { buffer = target.buffer, silent = true, nowait = true }
  for lhs, action in pairs({ p = "projects", a = "areas", r = "resources", x = "archives" }) do
    vim.keymap.set("n", lhs, function()
      M._action(action)
    end, vim.tbl_extend("force", options, { desc = "Obsidian PARA: sort into " .. action }))
  end
  vim.keymap.set("n", "e", function()
    M._action("perform_now")
  end, vim.tbl_extend("force", options, { desc = "Obsidian PARA: do now" }))
  vim.keymap.set("n", "s", function()
    M._action("skip")
  end, vim.tbl_extend("force", options, { desc = "Obsidian PARA: skip note" }))
  vim.keymap.set("n", "d", function()
    M._action("delete")
  end, vim.tbl_extend("force", options, { desc = "Obsidian PARA: move note to trash" }))
  vim.keymap.set("n", "q", function()
    M._action("quit")
  end, vim.tbl_extend("force", options, { desc = "Obsidian PARA: quit review" }))
end

local function clear_action_mappings(target)
  if not target or not vim.api.nvim_buf_is_valid(target.buffer) then
    return
  end
  for _, lhs in ipairs({ "p", "a", "r", "x", "d", "e", "s", "q" }) do
    pcall(vim.keymap.del, "n", lhs, { buffer = target.buffer })
  end
end

local function refresh_after_transaction()
  local target = current.target
  if vim.api.nvim_buf_is_valid(target.buffer) then
    pcall(vim.api.nvim_buf_call, target.buffer, function()
      vim.cmd("silent edit!")
    end)
  end
  target.fingerprint = file_fingerprint(target.full_path)
end

local function halt_transaction(result)
  local recovery = result.recovery
  local details = {
    source = recovery.source,
    destination = recovery.destination,
    failure = recovery.failure,
    changed_properties = recovery.changed_properties,
    rollback_failures = recovery.rollback_failures,
  }
  current.session:halt("PARA transaction rollback was incomplete", details)
  clear_action_mappings(current.target)
  local options = { buffer = current.target.buffer, silent = true, nowait = true }
  vim.keymap.set("n", "q", function()
    M._action("quit")
  end, vim.tbl_extend("force", options, { desc = "Obsidian PARA: quit halted review" }))
  current.view:render({
    status = { "Inbox review HALTED · recovery required · " .. recovery.source },
    footer = { "q Quit · inspect :messages for the recovery report" },
  })
  local failures = {}
  for _, failure in ipairs(recovery.rollback_failures) do
    table.insert(
      failures,
      ("%s (%s): %s"):format(failure.property, failure.action, failure.message)
    )
  end
  ui.notify_error(
    ("Transaction failed: %s. Rollback failures: %s. Source: %s. Destination: %s"):format(
      recovery.failure,
      table.concat(failures, "; "),
      recovery.source,
      recovery.destination
    )
  )
end

local function sort_into(category)
  local active = current
  local note = active.session:current()
  active.pending_action = "sort_prepare"
  sorting.prepare(config.get(), note, category, function(prepared)
    if current ~= active then
      return
    end
    active.pending_action = nil
    if not prepared.ok then
      if prepared.kind ~= "canceled" then
        ui.notify_error(prepared.message or "Could not prepare PARA transaction")
      end
      return
    end
    if not save_current() then
      return
    end

    active.pending_action = "sort_snapshot"
    cli.properties(config.get().vault, note.path, function(properties_result)
      if current ~= active then
        return
      end
      if not properties_result.ok then
        active.pending_action = nil
        ui.notify_error(properties_result.message)
        return
      end
      local plan, plan_error = metadata.operation_plan(
        note.path,
        prepared.destination,
        category,
        properties_result.data,
        prepared.context,
        config.get().para
      )
      if not plan or #plan.preflight.missing > 0 then
        active.pending_action = nil
        ui.notify_error(
          plan_error
            or ("Missing required metadata: " .. table.concat(plan.preflight.missing, ", "))
        )
        return
      end

      active.pending_action = "sort_transaction"
      transaction.execute(config.get().vault, plan, function(result)
        if current ~= active then
          return
        end
        active.pending_action = nil
        if not result.ok then
          refresh_after_transaction()
          if result.kind == "rollback" then
            halt_transaction(result)
          else
            ui.notify_error(result.message or "PARA transaction failed and was rolled back")
          end
          return
        end

        local moved_path = vim.fs.joinpath(active.vault_root, result.destination)
        pcall(vim.api.nvim_buf_set_name, active.target.buffer, moved_path)
        active.target.full_path = moved_path
        active.session:complete(category)
        show_current_note()
      end)
    end)
  end)
end

local function notify_finished(snapshot)
  vim.notify(
    ("obsidian-para-flow: Review finished: %d processed, %d skipped, %d remaining in Inbox"):format(
      snapshot.processed,
      snapshot.skipped,
      snapshot.skipped
    ),
    vim.log.levels.INFO
  )
end

local function close_review()
  current.view:close()
end

show_current_note = function()
  local snapshot = current.session:snapshot()
  if not snapshot.current then
    clear_action_mappings(current.target)
    close_review()
    notify_finished(snapshot)
    return false
  end

  local target, open_error = open_note_buffer(current.vault_root, snapshot.current)
  if not target then
    ui.notify_error(open_error)
    return false
  end
  clear_action_mappings(current.target)
  current.target = target
  current.view.buffers.body = target.buffer
  vim.api.nvim_win_set_buf(current.view.windows.body, target.buffer)
  vim.api.nvim_set_current_win(current.view.windows.body)
  current.view:render({ status = status_lines(snapshot), footer = footer })
  set_action_mappings(target)
  return true
end

save_current = function()
  local target = current.target
  if not vim.deep_equal(target.fingerprint, file_fingerprint(target.full_path)) then
    ui.notify_error("The current note changed outside Neovim; action canceled")
    return false
  end

  if vim.bo[target.buffer].modified then
    local ok, write_error = pcall(vim.api.nvim_buf_call, target.buffer, function()
      vim.cmd("silent write")
    end)
    if not ok then
      ui.notify_error("Could not save the current note: " .. tostring(write_error))
      return false
    end
  end
  target.fingerprint = file_fingerprint(target.full_path)
  return true
end

local function perform_now()
  if not save_current() then
    return
  end
  local target = current.target
  current.session:pause("perform_now")
  clear_action_mappings(target)
  close_review()
  vim.api.nvim_win_set_buf(0, target.buffer)
end

local function skip()
  if not save_current() then
    return
  end
  current.session:skip()
  show_current_note()
end

local function delete()
  if not save_current() then
    return
  end

  local active = current
  local note = active.session:current()
  active.pending_action = "delete_confirmation"
  ui.select({ "Cancel", "Move to trash" }, {
    prompt = ("Move `%s` to the Obsidian trash?"):format(note.path),
  }, function(choice)
    if current ~= active then
      return
    end
    active.pending_action = nil
    if choice ~= "Move to trash" then
      return
    end

    active.pending_action = "delete"
    cli.trash(config.get().vault, note.path, function(result)
      if current ~= active then
        return
      end
      active.pending_action = nil
      if not result.ok then
        ui.notify_error(result.message or ("Could not move `%s` to trash"):format(note.path))
        return
      end
      active.session:complete("delete")
      show_current_note()
    end)
  end)
end

local function finish_quit()
  clear_action_mappings(current.target)
  close_review()
  current = nil
end

local function quit()
  local target = current.target
  if not vim.bo[target.buffer].modified then
    finish_quit()
    return
  end

  ui.select({ "Cancel", "Save and exit", "Discard and exit" }, {
    prompt = "The current note has unsaved changes:",
  }, function(choice)
    if choice == "Save and exit" then
      if save_current() then
        finish_quit()
      end
    elseif choice == "Discard and exit" then
      vim.api.nvim_buf_call(target.buffer, function()
        vim.cmd("silent edit!")
      end)
      finish_quit()
    end
  end)
end

local function open_session(cfg, notes, vault_root)
  local review_session = session.new(notes)
  local snapshot = review_session:snapshot()
  if not snapshot.current then
    vim.notify("obsidian-para-flow: Inbox is empty", vim.log.levels.INFO)
    return
  end

  local target, open_error = open_note_buffer(vault_root, snapshot.current)
  if not target then
    ui.notify_error(open_error)
    return
  end
  local view = ui.open_review({
    layout = cfg.review.layout,
    width = cfg.review.width,
    height = cfg.review.height,
    body_buffer = target.buffer,
    status = status_lines(snapshot),
    footer = footer,
  })
  current = {
    session = review_session,
    view = view,
    vault_root = vault_root,
    target = target,
  }
  set_action_mappings(target)
end

function M.start()
  local cfg = config.get()
  inbox.load(function(inbox_result)
    if not inbox_result.ok then
      ui.notify_error(inbox_result.message)
      return
    end

    cli.vault_info(cfg.vault, "path", function(path_result)
      if not path_result.ok or path_result.stdout == "" then
        ui.notify_error(path_result.message or "Obsidian CLI returned an empty vault path")
        return
      end
      open_session(cfg, inbox_result.data, path_result.stdout)
    end)
  end)
end

function M._action(action)
  if not current or not current.view:is_valid() then
    return
  end
  if current.pending_action then
    return
  end
  if action == "perform_now" then
    perform_now()
  elseif action == "skip" then
    skip()
  elseif action == "delete" then
    delete()
  elseif action == "quit" then
    quit()
  elseif vim.tbl_contains({ "projects", "areas", "resources", "archives" }, action) then
    if current.session:snapshot().status == "active" then
      sort_into(action)
    end
  else
    error(("obsidian-para-flow: unknown review action `%s`"):format(tostring(action)), 0)
  end
end

function M._current()
  return current
end

function M._reset()
  if current then
    clear_action_mappings(current.target)
  end
  if current and current.view:is_valid() then
    current.view:close()
  end
  current = nil
end

return M
