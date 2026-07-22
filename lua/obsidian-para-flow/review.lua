local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local conflict = require("obsidian-para-flow.conflict")
local inbox = require("obsidian-para-flow.inbox")
local merge_transaction = require("obsidian-para-flow.merge_transaction")
local metadata = require("obsidian-para-flow.metadata")
local session = require("obsidian-para-flow.session")
local sorting = require("obsidian-para-flow.sorting")
local transaction = require("obsidian-para-flow.transaction")
local ui = require("obsidian-para-flow.ui")

local M = {}
local current
local save_current
local show_current_note
local open_conflict
local execute_sort

local footer = {
  "p Project · a Area · r Resource · x Archive · d Delete · e Do now · s Skip · q Quit",
}

local conflict_footer =
  { "m Merge · r Rename Inbox note · d Delete Inbox note · q Back · <Tab> Focus" }
local preview_footer = { "<leader>om Apply merge · <leader>oq Back to comparison" }

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

local function open_compare_buffer(vault_root, path)
  local full_path = vim.fs.joinpath(vault_root, path)
  if not file_fingerprint(full_path) then
    return nil, ("Destination note no longer exists: %s"):format(path)
  end
  local ok, lines = pcall(vim.fn.readfile, full_path)
  if not ok then
    return nil, ("Could not read destination note: %s"):format(path)
  end
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = "hide"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].filetype = "markdown"
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
  vim.bo[buffer].readonly = true
  return buffer
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

local function set_conflict_mappings(buffer)
  local options = { buffer = buffer, silent = true, nowait = true }
  for lhs, action in pairs({
    m = "conflict_merge",
    r = "conflict_rename",
    d = "conflict_delete",
    q = "conflict_quit",
  }) do
    vim.keymap.set("n", lhs, function()
      M._action(action)
    end, vim.tbl_extend("force", options, { desc = "Obsidian PARA: " .. action:gsub("_", " ") }))
  end
  vim.keymap.set("n", "<Tab>", function()
    M._action("conflict_focus")
  end, vim.tbl_extend("force", options, { desc = "Obsidian PARA: switch conflict pane" }))
end

local function clear_conflict_mappings(buffer)
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    return
  end
  for _, lhs in ipairs({ "m", "r", "d", "q", "<Tab>" }) do
    pcall(vim.keymap.del, "n", lhs, { buffer = buffer })
  end
end

local function clear_preview(preview)
  if not preview or not vim.api.nvim_buf_is_valid(preview.buffer) then
    return
  end
  pcall(vim.keymap.del, "n", "<leader>om", { buffer = preview.buffer })
  pcall(vim.keymap.del, "n", "<leader>oq", { buffer = preview.buffer })
  pcall(vim.api.nvim_buf_delete, preview.buffer, { force = true })
end

local function conflict_status(prepared)
  return { "Destination conflict · " .. prepared.destination }
end

local function leave_conflict()
  local state = current.conflict
  if not state then
    return
  end
  clear_conflict_mappings(state.target_buffer)
  clear_conflict_mappings(current.target.buffer)
  local preview = state.preview
  current.view:restore_review(current.target.buffer, {
    status = status_lines(current.session:snapshot()),
    footer = footer,
  })
  clear_preview(preview)
  if vim.api.nvim_buf_is_valid(state.target_buffer) then
    pcall(vim.api.nvim_buf_delete, state.target_buffer, { force = true })
  end
  current.conflict = nil
  set_action_mappings(current.target)
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

execute_sort = function(active, note, category, prepared)
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
        plan_error or ("Missing required metadata: " .. table.concat(plan.preflight.missing, ", "))
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
        if active.conflict then
          leave_conflict()
        end
        if result.kind == "rollback" then
          halt_transaction(result)
        else
          ui.notify_error(result.message or "PARA transaction failed and was rolled back")
        end
        return
      end

      if active.conflict then
        leave_conflict()
      end
      local moved_path = vim.fs.joinpath(active.vault_root, result.destination)
      pcall(vim.api.nvim_buf_set_name, active.target.buffer, moved_path)
      active.target.full_path = moved_path
      active.session:complete(category)
      show_current_note()
    end)
  end)
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
      if prepared.kind == "conflict" then
        if save_current() then
          open_conflict(prepared)
        end
      elseif prepared.kind ~= "canceled" then
        ui.notify_error(prepared.message or "Could not prepare PARA transaction")
      end
      return
    end
    if not save_current() then
      return
    end
    execute_sort(active, note, category, prepared)
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

local function conflict_focus()
  local windows = current.view.windows
  if vim.api.nvim_get_current_win() == windows.body then
    vim.api.nvim_set_current_win(windows.compare_inbox)
  else
    vim.api.nvim_set_current_win(windows.body)
  end
end

local function conflict_delete()
  local active = current
  local note = active.session:current()
  active.pending_action = "conflict_delete_confirmation"
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
    active.pending_action = "conflict_delete"
    cli.trash(config.get().vault, note.path, function(result)
      if current ~= active then
        return
      end
      active.pending_action = nil
      if not result.ok then
        ui.notify_error(result.message or ("Could not move `%s` to trash"):format(note.path))
        return
      end
      leave_conflict()
      active.session:complete("delete")
      show_current_note()
    end)
  end)
end

local function conflict_rename()
  local active = current
  local state = active.conflict
  active.pending_action = "conflict_rename_input"
  ui.input({ prompt = "New note name: " }, function(value)
    if current ~= active then
      return
    end
    active.pending_action = nil
    if value == nil then
      return
    end
    local filename, name_error = conflict.normalize_name(value)
    if not filename then
      ui.notify_error(name_error)
      return
    end
    active.pending_action = "conflict_rename_preflight"
    sorting.rename_preflight(
      config.get(),
      active.session:current(),
      state.prepared,
      filename,
      function(prepared)
        if current ~= active then
          return
        end
        active.pending_action = nil
        if prepared.kind == "conflict" then
          leave_conflict()
          open_conflict(prepared)
        elseif not prepared.ok then
          if prepared.kind ~= "canceled" then
            ui.notify_error(prepared.message or "Could not validate the new note name")
          end
        else
          execute_sort(active, active.session:current(), prepared.category, prepared)
        end
      end
    )
  end)
end

local function back_to_comparison()
  local state = current.conflict
  local preview = state.preview
  local function discard()
    current.view:show_compare_again({
      status = conflict_status(state.prepared),
      footer = conflict_footer,
    })
    state.preview = nil
    clear_preview(preview)
  end
  if not vim.bo[preview.buffer].modified then
    discard()
    return
  end
  ui.select({ "Cancel", "Discard preview" }, {
    prompt = "The merge preview has unsaved changes:",
  }, function(choice)
    if choice == "Discard preview" then
      discard()
    end
  end)
end

local function halt_merge(result)
  local recovery = result.recovery
  current.session:halt("Merge rollback was incomplete", recovery)
  clear_conflict_mappings(current.conflict.target_buffer)
  clear_conflict_mappings(current.target.buffer)
  local preview = current.conflict.preview
  current.view:restore_review(current.target.buffer, {
    status = { "Inbox review HALTED · merge recovery required · " .. recovery.target },
    footer = { "q Quit · inspect :messages for the recovery report" },
  })
  clear_preview(preview)
  if vim.api.nvim_buf_is_valid(current.conflict.target_buffer) then
    pcall(vim.api.nvim_buf_delete, current.conflict.target_buffer, { force = true })
  end
  current.conflict = nil
  local options = { buffer = current.target.buffer, silent = true, nowait = true }
  vim.keymap.set("n", "q", function()
    M._action("quit")
  end, vim.tbl_extend("force", options, { desc = "Obsidian PARA: quit halted review" }))
  ui.notify_error(
    ("Merge failed: %s. Target: %s. Source: %s. Rollback failed: %s"):format(
      result.message,
      recovery.target,
      recovery.source,
      recovery.rollback_failure
    )
  )
end

local function apply_merge()
  local active = current
  local state = active.conflict
  local preview = state.preview
  local lines = vim.api.nvim_buf_get_lines(preview.buffer, 0, -1, false)
  local content = table.concat(lines, "\n") .. "\n"
  active.pending_action = "merge_preflight"
  cli.read(config.get().vault, state.prepared.destination, function(target_result)
    if current ~= active then
      return
    end
    if not target_result.ok or target_result.stdout ~= preview.target_snapshot then
      active.pending_action = nil
      ui.notify_error(
        target_result.message or "The destination note changed after the merge preview was built"
      )
      return
    end
    cli.read(config.get().vault, active.session:current().path, function(source_result)
      if current ~= active then
        return
      end
      if not source_result.ok or source_result.stdout ~= preview.source_snapshot then
        active.pending_action = nil
        ui.notify_error(
          source_result.message or "The Inbox note changed after the merge preview was built"
        )
        return
      end
      active.pending_action = "merge_transaction"
      merge_transaction.execute(config.get().vault, {
        target = state.prepared.destination,
        source = active.session:current().path,
        target_snapshot = preview.target_snapshot,
        content = content,
      }, function(result)
        if current ~= active then
          return
        end
        active.pending_action = nil
        if not result.ok then
          if result.kind == "rollback" then
            halt_merge(result)
          else
            back_to_comparison()
            ui.notify_error(result.message or "Merge failed and the destination was restored")
          end
          return
        end
        leave_conflict()
        active.session:complete("merge")
        show_current_note()
      end)
    end)
  end)
end

local function open_merge_preview()
  local active = current
  local state = active.conflict
  local note = active.session:current()
  active.pending_action = "merge_preview"
  cli.read(config.get().vault, state.prepared.destination, function(target_content)
    if current ~= active then
      return
    end
    if not target_content.ok then
      active.pending_action = nil
      ui.notify_error(target_content.message)
      return
    end
    cli.read(config.get().vault, note.path, function(source_content)
      if current ~= active then
        return
      end
      if not source_content.ok then
        active.pending_action = nil
        ui.notify_error(source_content.message)
        return
      end
      cli.properties(config.get().vault, state.prepared.destination, function(target_properties)
        if current ~= active then
          return
        end
        if not target_properties.ok then
          active.pending_action = nil
          ui.notify_error(target_properties.message)
          return
        end
        cli.properties(config.get().vault, note.path, function(source_properties)
          if current ~= active then
            return
          end
          active.pending_action = nil
          if not source_properties.ok then
            ui.notify_error(source_properties.message)
            return
          end
          local content, compose_error = conflict.compose({
            category = state.prepared.category,
            context = state.prepared.context,
            para = config.get().para,
            target_content = target_content.stdout,
            source_content = source_content.stdout,
            target_properties = target_properties.data,
            source_properties = source_properties.data,
          })
          if not content then
            ui.notify_error(compose_error)
            return
          end
          local buffer = vim.api.nvim_create_buf(false, false)
          vim.bo[buffer].bufhidden = "wipe"
          vim.bo[buffer].swapfile = false
          vim.bo[buffer].filetype = "markdown"
          vim.api.nvim_buf_set_lines(
            buffer,
            0,
            -1,
            false,
            vim.split(content:gsub("\n$", ""), "\n", { plain = true })
          )
          vim.bo[buffer].modified = false
          state.preview = {
            buffer = buffer,
            target_snapshot = target_content.stdout,
            source_snapshot = source_content.stdout,
          }
          vim.keymap.set("n", "<leader>om", apply_merge, {
            buffer = buffer,
            silent = true,
            desc = "Obsidian PARA: apply merge",
          })
          vim.keymap.set("n", "<leader>oq", back_to_comparison, {
            buffer = buffer,
            silent = true,
            desc = "Obsidian PARA: cancel merge preview",
          })
          active.view:show_preview(buffer, {
            status = { "Merge Preview · " .. state.prepared.destination },
            footer = preview_footer,
          })
        end)
      end)
    end)
  end)
end

open_conflict = function(prepared)
  local target_buffer, open_error = open_compare_buffer(current.vault_root, prepared.destination)
  if not target_buffer then
    ui.notify_error(open_error)
    return
  end
  clear_action_mappings(current.target)
  current.conflict = {
    prepared = prepared,
    target_buffer = target_buffer,
  }
  set_conflict_mappings(target_buffer)
  set_conflict_mappings(current.target.buffer)
  current.view:show_compare(target_buffer, current.target.buffer, {
    status = conflict_status(prepared),
    footer = conflict_footer,
  })
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
  elseif action == "conflict_focus" and current.conflict and not current.conflict.preview then
    conflict_focus()
  elseif action == "conflict_quit" and current.conflict and not current.conflict.preview then
    leave_conflict()
  elseif action == "conflict_delete" and current.conflict and not current.conflict.preview then
    conflict_delete()
  elseif action == "conflict_rename" and current.conflict and not current.conflict.preview then
    conflict_rename()
  elseif action == "conflict_merge" and current.conflict and not current.conflict.preview then
    open_merge_preview()
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
  local conflict_state = current and current.conflict
  if current then
    clear_action_mappings(current.target)
    if conflict_state then
      clear_conflict_mappings(conflict_state.target_buffer)
      clear_conflict_mappings(current.target.buffer)
    end
  end
  if current and current.view:is_valid() then
    current.view:close()
  end
  if conflict_state then
    clear_preview(conflict_state.preview)
    if vim.api.nvim_buf_is_valid(conflict_state.target_buffer) then
      pcall(vim.api.nvim_buf_delete, conflict_state.target_buffer, { force = true })
    end
  end
  current = nil
end

return M
