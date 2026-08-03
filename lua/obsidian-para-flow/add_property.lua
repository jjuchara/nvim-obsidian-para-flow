local cli = require("obsidian-para-flow.cli")
local current_note = require("obsidian-para-flow.current_note_property")
local ui = require("obsidian-para-flow.ui")

local M = {}

local function is_date_property(context, property)
  return vim.tbl_contains(context.cfg.metadata.date_properties, property)
end

function M.start()
  current_note.prepare(function(context)
    cli.property_names(context.cfg.vault, function(names_result)
      if not names_result.ok then
        ui.notify_error(names_result.message)
        return
      end
      if #names_result.data == 0 then
        ui.notify_error("No known vault properties were found")
        return
      end
      ui.select(names_result.data, { prompt = "Property: " }, function(property)
        if not property then
          return
        end
        if is_date_property(context, property) then
          require("obsidian-para-flow.date_property").pick(context, property)
          return
        end
        local current = context.properties[property]
        local default = type(current) == "string" and current or nil
        ui.input({ prompt = ("Set %s: "):format(property), default = default }, function(value)
          if value ~= nil then
            current_note.write(context, property, value, nil)
          end
        end)
      end)
    end)
  end)
end

return M
