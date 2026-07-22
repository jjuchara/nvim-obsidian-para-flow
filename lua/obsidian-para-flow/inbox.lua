local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local ui = require("obsidian-para-flow.ui")

local M = {}

local function folder_prefix(folder)
  return folder:gsub("/+$", "") .. "/"
end

function M._validate_title(value)
  if value == nil then
    return nil
  end

  local title = vim.trim(value)
  if title == "" then
    return nil, "Inbox note title cannot be empty"
  end
  if title == "." or title == ".." or title:find('[\\/:*?"<>|]') then
    return nil, "Inbox note title cannot contain path separators or reserved filename characters"
  end
  return title
end

function M._target_path(folder, title)
  local filename = title:lower():sub(-3) == ".md" and title or (title .. ".md")
  return folder_prefix(folder) .. filename
end

local function contains_path(paths, target)
  target = target:lower()
  for _, path in ipairs(paths) do
    if path:lower() == target then
      return true
    end
  end
  return false
end

function M._discover_created(before, after, folder)
  local known = {}
  for _, path in ipairs(before) do
    known[path] = true
  end

  local prefix = folder_prefix(folder)
  local created = {}
  for _, path in ipairs(after) do
    if not known[path] and path:sub(1, #prefix) == prefix and path:match("%.md$") then
      table.insert(created, path)
    end
  end
  table.sort(created)
  return created
end

function M._find_body_line(lines)
  if #lines == 0 then
    return 1
  end

  local candidate = 1
  if vim.trim(lines[1]) == "---" then
    for index = 2, #lines do
      if vim.trim(lines[index]) == "---" then
        candidate = index + 1
        break
      end
    end
  end

  local heading = candidate
  while heading <= #lines and lines[heading]:match("^%s*$") do
    heading = heading + 1
  end
  if heading <= #lines and lines[heading]:match("^#%s+") then
    return math.min(heading + 1, #lines)
  end
  return math.min(candidate, #lines)
end

local function open_created(vault_root, relative_path)
  local full_path = vim.fs.joinpath(vault_root, relative_path)
  vim.cmd.edit(vim.fn.fnameescape(full_path))
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  vim.api.nvim_win_set_cursor(0, { M._find_body_line(lines), 0 })
end

function M.new()
  local cfg = config.get()
  ui.input({ prompt = "Inbox note title: " }, function(value)
    local title, validation_error = M._validate_title(value)
    if validation_error then
      ui.notify_error(validation_error)
      return
    end
    if not title then
      return
    end

    cli.ensure_vault(cfg.vault, function(vault_result)
      if not vault_result.ok then
        ui.notify_error(vault_result.message)
        return
      end

      cli.list_files(cfg.vault, cfg.inbox.folder, function(before_result)
        if not before_result.ok then
          ui.notify_error(before_result.message)
          return
        end

        local target = M._target_path(cfg.inbox.folder, title)
        if contains_path(before_result.data, target) then
          ui.notify_error(("Inbox note already exists: %s"):format(target))
          return
        end

        cli.quickadd(
          cfg.vault,
          cfg.inbox.quickadd_choice,
          { title = title },
          function(quickadd_result)
            if not quickadd_result.ok then
              if quickadd_result.kind ~= "canceled" then
                ui.notify_error(quickadd_result.message)
              end
              return
            end

            cli.list_files(cfg.vault, cfg.inbox.folder, function(after_result)
              if not after_result.ok then
                ui.notify_error(after_result.message)
                return
              end
              local created =
                M._discover_created(before_result.data, after_result.data, cfg.inbox.folder)
              if #created ~= 1 then
                ui.notify_error(
                  #created == 0 and "QuickAdd completed but no new Inbox Markdown file was found"
                    or "QuickAdd created more than one Inbox Markdown file; refusing to choose one"
                )
                return
              end

              cli.vault_info(cfg.vault, "path", function(path_result)
                if not path_result.ok or path_result.stdout == "" then
                  ui.notify_error(
                    path_result.message or "Obsidian CLI returned an empty vault path"
                  )
                  return
                end
                open_created(path_result.stdout, created[1])
              end)
            end)
          end
        )
      end)
    end)
  end)
end

return M
