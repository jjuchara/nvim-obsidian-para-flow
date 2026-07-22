local M = {}

function M.valid()
  return {
    vault = "Test Vault",
    inbox = {
      folder = "6. Inbox",
      quickadd_choice = "inbox",
    },
    para = {
      projects = { folder = "1. Projects", link = "[[My Projects]]" },
      areas = { folder = "2. Areas", link = "[[My Areas]]" },
      resources = { folder = "3. Resources" },
      archives = { folder = "4. Archives" },
    },
  }
end

return M
