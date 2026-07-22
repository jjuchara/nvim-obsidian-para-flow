local M = {}
local input

function M.input(options, callback)
  local handler = input or vim.ui.input
  handler(options, callback)
end

function M.notify_error(message)
  vim.notify("obsidian-para-flow: " .. message, vim.log.levels.ERROR)
end

function M._set_input(value)
  input = value
end

function M._reset()
  input = nil
end

return M
