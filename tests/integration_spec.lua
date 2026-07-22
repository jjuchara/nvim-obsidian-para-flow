local T = MiniTest.new_set()

T["uses only the explicitly selected test vault"] = function()
  local vault = vim.env.OBSIDIAN_PARA_TEST_VAULT
  MiniTest.expect.equality(type(vault), "string")
  MiniTest.expect.no_equality(vault, "")

  local result = vim
    .system({ "obsidian", "vault=" .. vault, "vault", "info=name" }, { text = true })
    :wait()
  MiniTest.expect.equality(result.code, 0)
  MiniTest.expect.equality(vim.trim(result.stdout), vault)
end

return T
