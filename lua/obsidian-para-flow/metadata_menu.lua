local ui = require("obsidian-para-flow.ui")

local M = {}

local actions = {
  { key = "d", label = "Date property", value = "date" },
  { key = "a", label = "Add property", value = "add" },
}

function M.start()
  return ui.keyed_select(actions, { prompt = "Metadata" }, function(action)
    if action == "date" then
      require("obsidian-para-flow.date_property").start()
    elseif action == "add" then
      require("obsidian-para-flow.add_property").start()
    end
  end)
end

return M
