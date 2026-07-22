local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local inbox = require("obsidian-para-flow.inbox")
local session = require("obsidian-para-flow.session")
local ui = require("obsidian-para-flow.ui")

local M = {}
local current

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
  vim.keymap.set("n", "e", function()
    M._action("perform_now")
  end, vim.tbl_extend("force", options, { desc = "Obsidian PARA: do now" }))
  vim.keymap.set("n", "s", function()
    M._action("skip")
  end, vim.tbl_extend("force", options, { desc = "Obsidian PARA: skip note" }))
  vim.keymap.set("n", "q", function()
    M._action("quit")
  end, vim.tbl_extend("force", options, { desc = "Obsidian PARA: quit review" }))
end

local function clear_action_mappings(target)
  if not target or not vim.api.nvim_buf_is_valid(target.buffer) then
    return
  end
  for _, lhs in ipairs({ "e", "s", "q" }) do
    pcall(vim.keymap.del, "n", lhs, { buffer = target.buffer })
  end
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

local function show_current_note()
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

local function save_current()
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
  if action == "perform_now" then
    perform_now()
  elseif action == "skip" then
    skip()
  elseif action == "quit" then
    quit()
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
