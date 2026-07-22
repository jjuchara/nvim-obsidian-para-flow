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

local function open_note_buffer(vault_root, note)
  local full_path = vim.fs.joinpath(vault_root, note.path)
  local buffer = vim.fn.bufadd(full_path)
  vim.fn.bufload(buffer)
  vim.bo[buffer].buflisted = true
  vim.bo[buffer].modifiable = true
  vim.bo[buffer].readonly = false
  vim.bo[buffer].filetype = "markdown"
  return buffer
end

local function open_session(cfg, notes, vault_root)
  local review_session = session.new(notes)
  local snapshot = review_session:snapshot()
  if not snapshot.current then
    vim.notify("obsidian-para-flow: Inbox is empty", vim.log.levels.INFO)
    return
  end

  local body_buffer = open_note_buffer(vault_root, snapshot.current)
  local view = ui.open_review({
    layout = cfg.review.layout,
    width = cfg.review.width,
    height = cfg.review.height,
    body_buffer = body_buffer,
    status = status_lines(snapshot),
    footer = footer,
  })
  current = {
    session = review_session,
    view = view,
  }
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

function M._current()
  return current
end

function M._reset()
  if current and current.view:is_valid() then
    current.view:close()
  end
  current = nil
end

return M
