local config = require("obsidian-para-flow.config")
local cli = require("obsidian-para-flow.cli")

local M = {}

local function add(checks, name, status, message)
  table.insert(checks, { name = name, status = status, message = message })
end

function M.collect(callback, dependencies)
  local cfg = config.get()
  local adapter = (dependencies or {}).cli or cli
  local checks = {}
  local version = vim.version()
  local nvim_ok = version.major > 0 or version.minor >= 10
  add(checks, "Neovim", nvim_ok and "ok" or "error", vim.version().major .. "." .. version.minor)

  add(checks, "Picker", "ok", require("obsidian-para-flow.picker").backend(cfg))
  local has_ripgrep = vim.fn.executable("rg") == 1
  add(
    checks,
    "ripgrep",
    has_ripgrep and "ok" or "warn",
    has_ripgrep and "available" or "`rg` is missing; content search is unavailable"
  )

  if vim.fn.executable("obsidian") ~= 1 and not (dependencies or {}).skip_executable then
    add(checks, "Obsidian CLI", "error", "`obsidian` is not executable")
    callback(checks)
    return
  end

  adapter.version(cfg.vault, function(version_result)
    if not version_result.ok then
      add(checks, "Obsidian", "error", version_result.message)
      callback(checks)
      return
    end
    add(checks, "Obsidian", "ok", version_result.stdout)

    adapter.vault_info(cfg.vault, "name", function(vault_result)
      if not vault_result.ok or vault_result.stdout ~= cfg.vault then
        add(checks, "Vault", "error", vault_result.message or "open vault name does not match")
        callback(checks)
        return
      end
      add(checks, "Vault", "ok", vault_result.stdout)

      local choices = {
        { name = "QuickAdd choice", value = cfg.inbox.quickadd_choice },
      }
      local folders = {
        cfg.inbox.folder,
        cfg.para.projects.folder,
        cfg.para.areas.folder,
        cfg.para.resources.folder,
        cfg.para.archives.folder,
      }
      local profile_names = vim.tbl_keys(cfg.capture.profiles)
      table.sort(profile_names)
      for _, name in ipairs(profile_names) do
        local profile = cfg.capture.profiles[name]
        table.insert(choices, {
          name = "Capture " .. name .. " QuickAdd choice",
          value = profile.quickadd_choice,
        })
        table.insert(folders, profile.folder)
      end

      local function check_folders()
        local seen = {}
        local index = 1
        local function next_folder()
          local folder = folders[index]
          if not folder then
            callback(checks)
            return
          end
          index = index + 1
          if seen[folder] then
            next_folder()
            return
          end
          seen[folder] = true
          adapter.folder_info(cfg.vault, folder, function(folder_result)
            add(
              checks,
              "Folder " .. folder,
              folder_result.ok and "ok" or "error",
              folder_result.ok and "available" or folder_result.message
            )
            next_folder()
          end)
        end
        next_folder()
      end

      local choice_index = 1
      local function next_choice()
        local entry = choices[choice_index]
        if not entry then
          check_folders()
          return
        end
        adapter.quickadd_check(cfg.vault, entry.value, function(quickadd_result)
          local choice = quickadd_result.data and quickadd_result.data.choice
          add(
            checks,
            entry.name,
            quickadd_result.ok and choice and "ok" or "error",
            choice and (choice.name or entry.value)
              or quickadd_result.message
              or "choice is unavailable"
          )
          choice_index = choice_index + 1
          next_choice()
        end)
      end
      next_choice()
    end)
  end)
end

function M.run()
  M.collect(function(checks)
    vim.health.start("obsidian-para-flow")
    for _, check in ipairs(checks) do
      vim.health[check.status](check.name .. ": " .. check.message)
    end
  end)
end

return M
