local background = require("obsidian-para-flow.home_background")

local T = MiniTest.new_set()

T["renders the constellation and disables it explicitly"] = function()
  local fragments = background.render({ provider = "constellation" }, { width = 100, height = 30 })
  MiniTest.expect.equality(#fragments > 0, true)
  MiniTest.expect.equality(
    background.render({ provider = false }, { width = 100, height = 30 }),
    {}
  )
end

T["sanitizes custom providers and reports callback failures"] = function()
  local fragments = background.render({
    provider = function(context)
      return {
        { row = -2, col = context.width - 2, text = "abcdef" },
        { row = 2, col = 2, text = "bad\nline" },
        { row = "x", col = 1, text = "bad" },
      }
    end,
  }, { width = 10, height = 5 })
  MiniTest.expect.equality(fragments, { { row = 1, col = 8, text = "abc" } })

  local failed, message = background.render({
    provider = function()
      error("boom")
    end,
  }, { width = 10, height = 5 })
  MiniTest.expect.equality(failed, {})
  MiniTest.expect.equality(message:find("boom", 1, true) ~= nil, true)
end

return T
