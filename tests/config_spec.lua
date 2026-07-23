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
  MiniTest.expect.equality(result.mappings.new_with_task, false)
  MiniTest.expect.equality(result.mappings.capture, "<leader>ot")
  MiniTest.expect.equality(result.mappings.home, "<leader>oh")
  MiniTest.expect.equality(result.home, {
    preview_limit = 5,
    projects = { status_order = { "В работе", "Планируется" } },
    background = { provider = "constellation", intensity = 0.12 },
  })
  MiniTest.expect.equality(result.review, {
    layout = "float",
    width = 0.7,
    height = 0.7,
    winblend = 0,
  })
  MiniTest.expect.equality(result.vault, "Test Vault")
end

T["validates named capture profiles"] = function()
  local options = helpers.valid()
  options.capture = {
    profiles = {
      meeting = {
        label = "Meeting note",
        folder = "3. Resources/Meetings",
        quickadd_choice = "meeting",
        prompt = "Meeting title: ",
        todo = true,
      },
    },
  }
  local result = config.setup(options)
  MiniTest.expect.equality(result.capture.profiles.meeting.todo, true)

  for _, invalid in ipairs({
    { folder = "../Meetings", quickadd_choice = "meeting" },
    { folder = "Meetings", quickadd_choice = "" },
    { folder = "Meetings", quickadd_choice = "meeting", todo = "yes" },
  }) do
    options.capture.profiles.meeting = invalid
    MiniTest.expect.error(function()
      config.setup(options)
    end)
  end

  options.capture.profiles = {
    ["meeting notes"] = { folder = "Meetings", quickadd_choice = "meeting" },
  }
  MiniTest.expect.error(function()
    config.setup(options)
  end)
end

T["validates Home configuration and custom background providers"] = function()
  local options = helpers.valid()
  local provider = function()
    return {}
  end
  options.home = {
    preview_limit = 3,
    projects = { status_order = { "Active" } },
    background = { provider = provider, intensity = 0.5 },
  }
  local result = config.setup(options)
  MiniTest.expect.equality(result.home.preview_limit, 3)
  MiniTest.expect.equality(result.home.background.provider, provider)

  for _, invalid in ipairs({ 0, 1.5, "5" }) do
    options.home.preview_limit = invalid
    MiniTest.expect.error(function()
      config.setup(options)
    end)
  end
  options.home.preview_limit = 3
  for _, invalid in ipairs({ -0.1, 1.1, "0.5" }) do
    options.home.background.intensity = invalid
    MiniTest.expect.error(function()
      config.setup(options)
    end)
  end
  options.home.background.intensity = 0.5
  options.home.background.provider = "unknown"
  MiniTest.expect.error(function()
    config.setup(options)
  end)
end

T["validates the find prefix and the search provider"] = function()
  MiniTest.expect.equality(config.setup(helpers.valid()).mappings.find, "<leader>of")
  MiniTest.expect.equality(config.setup(helpers.valid()).search.provider, "auto")

  for _, provider in ipairs({ "snacks", "fzf-lua", "telescope", "builtin" }) do
    local options = helpers.valid()
    options.search = { provider = provider }
    MiniTest.expect.equality(config.setup(options).search.provider, provider)
  end

  local disabled = helpers.valid()
  disabled.mappings = { find = false }
  MiniTest.expect.equality(config.setup(disabled).mappings.find, false)

  for _, invalid in ipairs({ "fzf", "", true }) do
    local options = helpers.valid()
    options.search = { provider = invalid }
    MiniTest.expect.error(function()
      config.setup(options)
    end)
  end

  local bad_prefix = helpers.valid()
  bad_prefix.mappings = { find = "" }
  MiniTest.expect.error(function()
    config.setup(bad_prefix)
  end)
end

T["validates review transparency"] = function()
  for _, value in ipairs({ 0, 10, 100 }) do
    local options = helpers.valid()
    options.review = { winblend = value }
    MiniTest.expect.equality(config.setup(options).review.winblend, value)
  end

  for _, value in ipairs({ -1, 10.5, 101, "10" }) do
    local options = helpers.valid()
    options.review = { winblend = value }
    MiniTest.expect.error(function()
      config.setup(options)
    end)
  end
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
