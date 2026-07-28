local calendar = require("obsidian-para-flow.calendar")
local date = require("obsidian-para-flow.date")
local date_picker = require("obsidian-para-flow.date_picker")
local ui = require("obsidian-para-flow.ui")

local T = MiniTest.new_set({
  hooks = {
    post_case = function()
      ui._reset()
    end,
  },
})

local function mapping(buffer, description)
  for _, value in ipairs(vim.api.nvim_buf_get_keymap(buffer, "n")) do
    if value.desc == description then
      return value.callback
    end
  end
end

T["builds leap-year grids and clamps month navigation"] = function()
  local days = {}
  for _, week in ipairs(calendar.month_grid("2024-02-01")) do
    for column = 1, 7 do
      if week[column] then
        days[#days + 1] = week[column]
      end
    end
  end

  MiniTest.expect.equality(#days, 29)
  MiniTest.expect.equality(days[1], 1)
  MiniTest.expect.equality(days[#days], 29)
  MiniTest.expect.equality(date.add_days("2024-02-28", 1), "2024-02-29")
  MiniTest.expect.equality(date.add_days("2024-02-29", 1), "2024-03-01")
  MiniTest.expect.equality(date.add_months("2024-01-31", 1), "2024-02-29")
end

T["returns explicit select and cancel results"] = function()
  local result
  local instance = calendar.open({ initial = "2024-01-31" }, function(value)
    result = value
  end)
  MiniTest.expect.equality(vim.bo[instance.buffer].filetype, "obsidian-para-flow-calendar")
  mapping(instance.buffer, "Next day")()
  mapping(instance.buffer, "Confirm date")()
  MiniTest.expect.equality(result, { action = "select", value = "2024-02-01" })

  result = nil
  instance = calendar.open({ initial = "2024-02-01" }, function(value)
    result = value
  end)
  mapping(instance.buffer, "Cancel date")()
  MiniTest.expect.equality(result, { action = "cancel" })
end

T["keeps the calendar open when manual input is cancelled"] = function()
  local result
  local instance = calendar.open({
    initial = "2024-02-01",
    manual = function(_, callback)
      callback({ action = "cancel" })
    end,
  }, function(value)
    result = value
  end)

  mapping(instance.buffer, "Enter date")()
  MiniTest.expect.equality(result, nil)
  MiniTest.expect.equality(vim.api.nvim_win_is_valid(instance.window), true)
  mapping(instance.buffer, "Cancel date")()
end

T["normalizes manual input and distinguishes cancellation"] = function()
  local result
  ui._set_input(function(options, callback)
    MiniTest.expect.equality(options.default, "2024-02-01")
    callback("29.02.2024")
  end)
  date_picker.input({ prompt = "Date: ", default = "2024-02-01" }, function(value)
    result = value
  end)
  MiniTest.expect.equality(result, { action = "select", value = "2024-02-29" })

  ui._set_input(function(_, callback)
    callback(nil)
  end)
  date_picker.input({ prompt = "Date: " }, function(value)
    result = value
  end)
  MiniTest.expect.equality(result, { action = "cancel" })
end

return T
