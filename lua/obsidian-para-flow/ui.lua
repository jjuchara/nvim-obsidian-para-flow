local M = {}

function M.notify_error(message)
  vim.notify("obsidian-para-flow: " .. message, vim.log.levels.ERROR)
end

return M
