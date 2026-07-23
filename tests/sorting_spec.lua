local cli = require("obsidian-para-flow.cli")
local sorting = require("obsidian-para-flow.sorting")
local ui = require("obsidian-para-flow.ui")

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      cli._reset()
      ui._reset()
    end,
    post_case = function()
      cli._reset()
      ui._reset()
    end,
  },
})

local cfg = {
  vault = "Vault",
  para = {
    projects = { folder = "1. Projects" },
    areas = { folder = "2. Areas" },
    resources = { folder = "3. Resources" },
    archives = { folder = "4. Archives" },
  },
}

local note = {
  path = "6. Inbox/Note.md",
  properties = {},
  file_created = 0,
}

local function executor(options)
  options = options or {}
  return function(argv, _, callback)
    local command = argv[2]
    if command == "folders" then
      callback({ code = 0, stdout = options.folders or "1. Projects/Z\n1. Projects/A", stderr = "" })
    elseif command == "search" then
      callback({ code = 0, stdout = options.areas or "2. Areas/Work.md", stderr = "" })
    elseif command == "file" then
      callback({ code = 0, stdout = "path 6. Inbox/Note.md\ncreated 1000", stderr = "" })
    elseif command == "folder" then
      callback({ code = 0, stdout = "ok", stderr = "" })
    elseif command == "files" then
      callback({ code = 0, stdout = options.files or "", stderr = "" })
    end
  end
end

T["puts category root first and sorts nested folders"] = function()
  MiniTest.expect.equality(
    sorting._folder_options("1. Projects", { "1. Projects/Z", "Elsewhere", "1. Projects/A" }),
    { "1. Projects", "1. Projects/A", "1. Projects/Z" }
  )
end

T["collects folder and area before successful preflight"] = function()
  cli._set_executor(executor())
  local selections = 0
  ui._set_select(function(items, _, callback)
    selections = selections + 1
    callback(selections == 1 and items[2] or items[1])
  end)
  local result

  sorting.prepare(cfg, note, "projects", function(value)
    result = value
  end)

  MiniTest.expect.equality(result.ok, true)
  MiniTest.expect.equality(result.destination, "1. Projects/A/Note.md")
  MiniTest.expect.equality(result.context.area, "[[2. Areas/Work]]")
end

T["cancels every interactive step before preflight mutations"] = function()
  for _, cancel_at in ipairs({ 1, 2 }) do
    cli._reset()
    ui._reset()
    cli._set_executor(executor())
    local selections = 0
    ui._set_select(function(items, _, callback)
      selections = selections + 1
      if selections == cancel_at then
        callback(nil)
      else
        callback(items[1])
      end
    end)
    local result
    sorting.prepare(cfg, note, "projects", function(value)
      result = value
    end)
    MiniTest.expect.equality(result.kind, "canceled")
  end
end

T["collects archive reason and detects destination conflicts"] = function()
  cli._set_executor(executor({ files = "4. Archives/Note.md" }))
  ui._set_select(function(items, _, callback)
    callback(items[1])
  end)
  ui._set_input(function(_, callback)
    callback("Completed")
  end)
  local result

  sorting.prepare(cfg, note, "archives", function(value)
    result = value
  end)

  MiniTest.expect.equality(result.kind, "conflict")
  MiniTest.expect.equality(result.destination, "4. Archives/Note.md")
end

T["cancels an archive reason prompt before preflight"] = function()
  cli._set_executor(executor())
  ui._set_select(function(items, _, callback)
    callback(items[1])
  end)
  ui._set_input(function(_, callback)
    callback(nil)
  end)
  local result

  sorting.prepare(cfg, note, "archives", function(value)
    result = value
  end)

  MiniTest.expect.equality(result.kind, "canceled")
end

return T
