local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local ui = require("obsidian-para-flow.ui")

local M = {}

local aliases = {
  ["daily"] = "open",
  ["daily:path"] = "path",
  ["daily:read"] = "read",
  ["daily:append"] = "append",
  ["daily:prepend"] = "prepend",
  today = "open",
  open = "open",
  path = "path",
  read = "read",
  append = "append",
  prepend = "prepend",
}

local completion = {
  "open",
  "path",
  "read",
  "append",
  "prepend",
  "daily",
  "daily:path",
  "daily:read",
  "daily:append",
  "daily:prepend",
  "today",
}

local function notify_error(result)
  ui.notify_error(result.message or "Obsidian Daily notes command failed")
end

local function open_scratch(content)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].filetype = "markdown"
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.split(content, "\n", { plain = true }))
  vim.bo[buffer].modifiable = false
  vim.cmd("tab sbuffer " .. buffer)
  vim.api.nvim_buf_set_name(buffer, "obsidian-para-flow://daily/read")
end

local function open_today(cfg)
  cli.daily_path(cfg.vault, function(path_result)
    if not path_result.ok then
      notify_error(path_result)
      return
    end
    local path = vim.trim(path_result.stdout)
    if
      path == ""
      or path:sub(1, 1) == "/"
      or path:find("\\", 1, true)
      or vim.tbl_contains(vim.split(path, "/", { plain = true }), "..")
    then
      ui.notify_error("Obsidian Daily notes returned an unsafe path")
      return
    end

    cli.daily(cfg.vault, function(daily_result)
      if not daily_result.ok then
        notify_error(daily_result)
        return
      end
      cli.vault_info(cfg.vault, "path", function(vault_result)
        if not vault_result.ok then
          notify_error(vault_result)
          return
        end
        local root = vim.trim(vault_result.stdout)
        vim.cmd("tabedit " .. vim.fn.fnameescape(vim.fs.joinpath(root, path)))
      end)
    end)
  end)
end

local function with_content(action, value, callback)
  if value ~= nil and value ~= "" then
    callback(value)
    return
  end
  ui.input(
    { prompt = (action == "append" and "Append" or "Prepend") .. " to Daily note: " },
    function(input)
      if input ~= nil and input ~= "" then
        callback(input)
      end
    end
  )
end

function M.run(action, content)
  local normalized = aliases[action or "daily"]
  if not normalized then
    ui.notify_error("Unknown Daily notes action: " .. tostring(action))
    return
  end

  local cfg = config.get()
  cli.ensure_vault(cfg.vault, function(vault_result)
    if not vault_result.ok then
      notify_error(vault_result)
      return
    end

    if normalized == "open" then
      open_today(cfg)
    elseif normalized == "path" then
      cli.daily_path(cfg.vault, function(result)
        if result.ok then
          vim.notify(result.stdout, vim.log.levels.INFO, { title = "Daily note path" })
        else
          notify_error(result)
        end
      end)
    elseif normalized == "read" then
      cli.daily_read(cfg.vault, function(result)
        if result.ok then
          open_scratch(result.stdout)
        else
          notify_error(result)
        end
      end)
    else
      with_content(normalized, content, function(value)
        local method = normalized == "append" and cli.daily_append or cli.daily_prepend
        method(cfg.vault, value, function(result)
          if not result.ok then
            notify_error(result)
          end
        end)
      end)
    end
  end)
end

function M.complete(argument)
  return vim.tbl_filter(function(value)
    return vim.startswith(value, argument)
  end, completion)
end

function M._aliases()
  return vim.deepcopy(aliases)
end

return M
