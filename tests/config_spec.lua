local helpers = require("tests.helpers.config")
local config = require("obsidian-para-flow.config")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      config._reset()
    end,
  },
})

T["valid configuration uses only UI and mapping defaults"] = function()
  local result = config.setup(helpers.valid())

  MiniTest.expect.equality(result.mappings.new, "<leader>on")
  MiniTest.expect.equality(result.review, { layout = "float", width = 0.85, height = 0.85 })
  MiniTest.expect.equality(result.vault, "Test Vault")
end

local missing_paths = {
  { "vault" },
  { "inbox" },
  { "inbox", "folder" },
  { "inbox", "quickadd_choice" },
  { "para" },
  { "para", "projects" },
  { "para", "projects", "folder" },
  { "para", "projects", "link" },
  { "para", "areas" },
  { "para", "areas", "folder" },
  { "para", "areas", "link" },
  { "para", "resources" },
  { "para", "resources", "folder" },
  { "para", "archives" },
  { "para", "archives", "folder" },
}

for _, path in ipairs(missing_paths) do
  T["rejects missing " .. table.concat(path, ".")] = function()
    local options = helpers.valid()
    local parent = options
    for index = 1, #path - 1 do
      parent = parent[path[index]]
    end
    parent[path[#path]] = nil

    MiniTest.expect.error(function()
      config.setup(options)
    end)
  end
end

T["validates fractional and exact review sizes"] = function()
  local options = helpers.valid()
  options.review = { layout = "fullscreen", width = 120, height = 0.5 }
  local result = config.setup(options)
  MiniTest.expect.equality(result.review.width, 120)

  for _, invalid in ipairs({ 0, -1, 1.5 }) do
    options.review.width = invalid
    MiniTest.expect.error(function()
      config.setup(options)
    end)
  end
end

T["rejects unsafe vault-relative folders"] = function()
  for _, path in ipairs({ "/Inbox", "../Inbox", "Folder\\Inbox" }) do
    local options = helpers.valid()
    options.inbox.folder = path
    MiniTest.expect.error(function()
      config.setup(options)
    end)
  end
end

return T
