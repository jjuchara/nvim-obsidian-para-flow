local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
local date = require("obsidian-para-flow.date")
local date_picker = require("obsidian-para-flow.date_picker")
local metadata = require("obsidian-para-flow.metadata")
local ui = require("obsidian-para-flow.ui")
local vault = require("obsidian-para-flow.vault")

local M = {}

local function normalized(path)
  return vim.uv.fs_realpath(path) or vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

function M.relative_path(root, path)
  root = normalized(root)
  path = normalized(path)
  local prefix = root:gsub("/+$", "") .. "/"
  if not vim.startswith(path, prefix) then
    return nil
  end
  local relative = path:sub(#prefix + 1)
  if relative == "" or relative:find("\\", 1, true) or not relative:lower():match("%.md$") then
    return nil
  end
  return relative
end

local function save_buffer(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) or vim.api.nvim_buf_get_name(buffer) == "" then
    return false, "Open a Markdown note from the configured vault first"
  end
  local ok, error_message = pcall(vim.api.nvim_buf_call, buffer, function()
    vim.cmd("silent update")
  end)
  if not ok then
    return false, "Could not save the current note: " .. tostring(error_message)
  end
  return true
end

local function choose_property(cfg, callback)
  if #cfg.metadata.date_properties == 0 then
    ui.notify_error("No known date properties are configured")
    return
  end
  ui.select(cfg.metadata.date_properties, { prompt = "Date property: " }, callback)
end

function M.start()
  local cfg = config.get()
  local buffer = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buffer) or vim.api.nvim_buf_get_name(buffer) == "" then
    ui.notify_error("Open a Markdown note from the configured vault first")
    return
  end
  local buffer_path = vim.api.nvim_buf_get_name(buffer)

  cli.ensure_vault(cfg.vault, function(vault_result)
    if not vault_result.ok then
      ui.notify_error(vault_result.message)
      return
    end
    vault.root(cfg, function(root_result)
      if not root_result.ok then
        ui.notify_error(root_result.message)
        return
      end
      local path = M.relative_path(root_result.root, buffer_path)
      if not path then
        ui.notify_error("The current buffer is not a Markdown note inside the configured vault")
        return
      end
      local saved, save_error = save_buffer(buffer)
      if not saved then
        ui.notify_error(save_error)
        return
      end
      local changedtick = vim.api.nvim_buf_get_changedtick(buffer)
      cli.properties(cfg.vault, path, function(snapshot_result)
        if not snapshot_result.ok then
          ui.notify_error(snapshot_result.message)
          return
        end
        choose_property(cfg, function(property)
          if not property then
            return
          end
          local initial = metadata.normalize_date(snapshot_result.data[property]) or date.today()
          date_picker.pick({
            picker = cfg.metadata.date_picker,
            title = "Set " .. property,
            prompt = ("Set %s (YYYY-MM-DD or DD.MM.YYYY): "):format(property),
            initial = initial,
          }, function(result)
            if result.action ~= "select" then
              return
            end
            if
              not vim.api.nvim_buf_is_valid(buffer)
              or vim.api.nvim_buf_get_changedtick(buffer) ~= changedtick
            then
              ui.notify_error("The note buffer changed while the date was being selected")
              return
            end
            cli.properties(cfg.vault, path, function(current_result)
              if not current_result.ok then
                ui.notify_error(current_result.message)
                return
              end
              if not vim.deep_equal(current_result.data, snapshot_result.data) then
                ui.notify_error("The note metadata changed while the date was being selected")
                return
              end
              cli.property_set(cfg.vault, path, property, result.value, "date", function(set_result)
                if not set_result.ok then
                  ui.notify_error(set_result.message or "Could not set the date property")
                  return
                end
                if vim.api.nvim_buf_is_valid(buffer) then
                  pcall(vim.api.nvim_buf_call, buffer, function()
                    vim.cmd("silent checktime")
                  end)
                end
                vim.notify(("obsidian-para-flow: set %s for `%s`"):format(property, path))
              end)
            end)
          end)
        end)
      end)
    end, { refresh = true })
  end)
end

return M
