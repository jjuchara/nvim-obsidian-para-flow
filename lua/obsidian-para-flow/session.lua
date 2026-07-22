local M = {}

local Session = {}
Session.__index = Session

local function require_active(self)
  if self._status ~= "active" then
    error(("obsidian-para-flow: review session is `%s`, expected `active`"):format(self._status), 0)
  end
end

local function advance(self)
  table.remove(self._queue, 1)
  if #self._queue == 0 then
    self._status = "finished"
  end
end

function Session:current()
  return self._queue[1]
end

function Session:complete(action)
  require_active(self)
  if type(action) ~= "string" or vim.trim(action) == "" then
    error("obsidian-para-flow: completed review action must be a non-empty string", 0)
  end

  self._processed = self._processed + 1
  self._actions[action] = (self._actions[action] or 0) + 1
  advance(self)
end

function Session:skip()
  require_active(self)
  local note = self:current()
  self._skipped[note.path] = true
  self._skipped_count = self._skipped_count + 1
  advance(self)
end

function Session:pause(reason)
  require_active(self)
  self._status = "paused"
  self._pause_reason = reason
end

function Session:halt(message, details)
  require_active(self)
  if type(message) ~= "string" or vim.trim(message) == "" then
    error("obsidian-para-flow: emergency message must be a non-empty string", 0)
  end

  self._status = "halted"
  self._emergency = {
    message = message,
    details = vim.deepcopy(details),
  }
end

function Session:snapshot()
  local skipped_paths = vim.tbl_keys(self._skipped)
  table.sort(skipped_paths)

  return {
    status = self._status,
    current = vim.deepcopy(self:current()),
    initial = self._initial_count,
    processed = self._processed,
    skipped = self._skipped_count,
    remaining = #self._queue,
    fully_processed = self._status == "finished" and self._skipped_count == 0,
    skipped_paths = skipped_paths,
    actions = vim.deepcopy(self._actions),
    pause_reason = self._pause_reason,
    emergency = vim.deepcopy(self._emergency),
  }
end

function M.new(notes)
  if type(notes) ~= "table" then
    error("obsidian-para-flow: review queue must be a table", 0)
  end

  local queue = {}
  local paths = {}
  for index, note in ipairs(notes) do
    if type(note) ~= "table" or type(note.path) ~= "string" or vim.trim(note.path) == "" then
      error(("obsidian-para-flow: review note %d must have a non-empty path"):format(index), 0)
    end
    if paths[note.path] then
      error(("obsidian-para-flow: duplicate review path `%s`"):format(note.path), 0)
    end
    paths[note.path] = true
    table.insert(queue, vim.deepcopy(note))
  end

  return setmetatable({
    _queue = queue,
    _initial_count = #queue,
    _processed = 0,
    _skipped = {},
    _skipped_count = 0,
    _actions = {},
    _status = #queue == 0 and "finished" or "active",
  }, Session)
end

return M
