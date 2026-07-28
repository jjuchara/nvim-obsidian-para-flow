local calendar = require("obsidian-para-flow.calendar")
local metadata = require("obsidian-para-flow.metadata")
local ui = require("obsidian-para-flow.ui")

local M = {}

local function input(options, callback)
  ui.input({ prompt = options.prompt, default = options.default }, function(value)
    if value == nil then
      callback({ action = "cancel" })
      return
    end
    value = vim.trim(value)
    if value == "" then
      callback({ action = "cancel" })
      return
    end
    local normalized = metadata.normalize_date(value)
    if not normalized then
      ui.notify_error("Expected a valid date in YYYY-MM-DD or DD.MM.YYYY format")
      input(options, callback)
      return
    end
    callback({ action = "select", value = normalized })
  end)
end

M.input = input

function M.pick(options, callback)
  if options.picker == "input" then
    input(options, callback)
    return
  end
  calendar.open({
    title = options.title,
    initial = options.initial,
    manual = function(selected, done)
      input({ prompt = options.prompt, default = selected }, done)
    end,
  }, callback)
end

return M
