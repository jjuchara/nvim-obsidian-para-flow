local filter_input = require("obsidian-para-flow.filter_input")

local T = MiniTest.new_set()

local function type_keys(query, keys)
  local step = { query = query, action = "continue" }
  for _, key in ipairs(keys) do
    step = filter_input.apply(step.query, key)
    if step.action ~= "continue" then
      return step
    end
  end
  return step
end

T["appends multibyte characters as they are typed"] = function()
  local step = type_keys("", { "р", "е", "с" })
  MiniTest.expect.equality(step.query, "рес")
  MiniTest.expect.equality(step.action, "continue")
end

T["deletes whole characters, not bytes"] = function()
  MiniTest.expect.equality(filter_input.apply("рес", "\8").query, "ре")
  MiniTest.expect.equality(filter_input.apply("рес", "\127").query, "ре")
  MiniTest.expect.equality(filter_input.apply("рес", "\128kb").query, "ре")
  MiniTest.expect.equality(filter_input.apply("", "\8").query, "")
end

T["clears the query and the last word"] = function()
  MiniTest.expect.equality(filter_input.apply("ресурсы 2024", "\21").query, "")
  MiniTest.expect.equality(filter_input.apply("ресурсы 2024", "\23").query, "ресурсы")
end

T["accepts on Enter and cancels on Esc"] = function()
  local accepted = type_keys("", { "р", "\13" })
  MiniTest.expect.equality(accepted.action, "accept")
  MiniTest.expect.equality(accepted.query, "р")

  local canceled = type_keys("", { "р", "\27" })
  MiniTest.expect.equality(canceled.action, "cancel")
end

T["ignores control keys and special sequences"] = function()
  MiniTest.expect.equality(filter_input.apply("рес", "\128ku").query, "рес")
  MiniTest.expect.equality(filter_input.apply("рес", "\1").query, "рес")
  MiniTest.expect.equality(filter_input.apply("рес", "").query, "рес")
end

return T
