local cli = require("obsidian-para-flow.cli")
local config = require("obsidian-para-flow.config")
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

function M.prepare(callback)
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
        callback({
          buffer = buffer,
          cfg = cfg,
          changedtick = changedtick,
          path = path,
          properties = snapshot_result.data,
        })
      end)
    end, { refresh = true })
  end)
end

function M.write(context, property, value, value_type)
  if
    not vim.api.nvim_buf_is_valid(context.buffer)
    or vim.api.nvim_buf_get_changedtick(context.buffer) ~= context.changedtick
  then
    ui.notify_error("The note buffer changed while metadata was being edited")
    return
  end
  cli.properties(context.cfg.vault, context.path, function(current_result)
    if not current_result.ok then
      ui.notify_error(current_result.message)
      return
    end
    if not vim.deep_equal(current_result.data, context.properties) then
      ui.notify_error("The note metadata changed while metadata was being edited")
      return
    end
    cli.property_set(
      context.cfg.vault,
      context.path,
      property,
      value,
      value_type,
      function(set_result)
        if not set_result.ok then
          ui.notify_error(set_result.message or "Could not set the note property")
          return
        end
        if vim.api.nvim_buf_is_valid(context.buffer) then
          pcall(vim.api.nvim_buf_call, context.buffer, function()
            vim.cmd("silent checktime")
          end)
        end
        vim.notify(("obsidian-para-flow: set %s for `%s`"):format(property, context.path))
      end
    )
  end)
end

return M
