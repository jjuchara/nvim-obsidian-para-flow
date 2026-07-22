if vim.env.OBSIDIAN_PARA_PROFILE ~= "dev" then
  return {}
end

local plugin_dir = assert(vim.env.OBSIDIAN_PARA_PLUGIN_DIR, "OBSIDIAN_PARA_PLUGIN_DIR is required")
local vault_name = assert(vim.env.OBSIDIAN_PARA_VAULT_NAME, "OBSIDIAN_PARA_VAULT_NAME is required")

return {
  -- selene: allow(mixed_table)
  {
    "jjuchara/nvim-obsidian-para-flow",
    dir = plugin_dir,
    opts = {
      vault = vault_name,
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
    },
  },
}
