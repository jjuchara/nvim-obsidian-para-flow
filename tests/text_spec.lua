local text = require("obsidian-para-flow.text")

local T = MiniTest.new_set()

T["folds Cyrillic and ASCII alike"] = function()
  MiniTest.expect.equality(text.fold("Ресурсы"), "ресурсы")
  MiniTest.expect.equality(text.fold("Resources"), "resources")
  MiniTest.expect.equality(text.fold(nil), "")
end

T["treats an uppercase query as case sensitive"] = function()
  MiniTest.expect.equality(text.is_case_sensitive("ресурс"), false)
  MiniTest.expect.equality(text.is_case_sensitive("Ресурс"), true)
  MiniTest.expect.equality(text.is_case_sensitive("Notes"), true)
end

T["matches case insensitively until the query has an uppercase letter"] = function()
  MiniTest.expect.equality(text.matches("Ресурсы 2024", "ресурсы"), true)
  MiniTest.expect.equality(text.matches("ресурсы 2024", "РЕСУРСЫ"), false)
  MiniTest.expect.equality(text.matches("Ресурсы 2024", "Ресурсы"), true)
  MiniTest.expect.equality(text.matches("Ресурсы 2024", ""), true)
end

T["requires every term to match some haystack"] = function()
  local fields = { "Ресурсы 2024", "3. Resources/Ресурсы 2024.md", "Работа" }
  MiniTest.expect.equality(text.matches_all(fields, "ресурсы работа"), true)
  MiniTest.expect.equality(text.matches_all(fields, "resources 2024"), true)
  MiniTest.expect.equality(text.matches_all(fields, "ресурсы отдых"), false)
  MiniTest.expect.equality(text.matches_all(fields, "   "), true)
  MiniTest.expect.equality(text.matches_all({}, "ресурсы"), false)
end

return T
