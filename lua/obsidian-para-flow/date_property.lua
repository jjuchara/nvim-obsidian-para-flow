local current_note = require("obsidian-para-flow.current_note_property")
local date = require("obsidian-para-flow.date")
local date_picker = require("obsidian-para-flow.date_picker")
local metadata = require("obsidian-para-flow.metadata")
local ui = require("obsidian-para-flow.ui")

local M = {
  relative_path = current_note.relative_path,
}

local function choose_property(cfg, callback)
  if #cfg.metadata.date_properties == 0 then
    ui.notify_error("No known date properties are configured")
    return
  end
  ui.select(cfg.metadata.date_properties, { prompt = "Date property: " }, callback)
end

function M.pick(context, property)
  local initial = metadata.normalize_date(context.properties[property]) or date.today()
  date_picker.pick({
    picker = context.cfg.metadata.date_picker,
    title = "Set " .. property,
    prompt = ("Set %s (YYYY-MM-DD or DD.MM.YYYY): "):format(property),
    initial = initial,
  }, function(result)
    if result.action == "select" then
      current_note.write(context, property, result.value, "date")
    end
  end)
end

function M.start()
  current_note.prepare(function(context)
    choose_property(context.cfg, function(property)
      if property then
        M.pick(context, property)
      end
    end)
  end)
end

return M
