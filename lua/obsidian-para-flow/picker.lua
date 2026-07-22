local ui = require("obsidian-para-flow.ui")
local vault = require("obsidian-para-flow.vault")

local M = {}

local markdown_files_command = { "rg", "--files", "--glob", "*.md" }

local function open_path(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
end

-- Walks the vault on disk rather than through the CLI: the fallback must work
-- for the whole vault as well as a single PARA folder, with no extra plugins.
local function builtin_files(_, options)
  local relative_paths = {}
  for name, kind in vim.fs.dir(options.cwd, { depth = 16 }) do
    if kind == "file" and name:match("%.[mM][dD]$") then
      table.insert(relative_paths, name)
    end
  end
  if #relative_paths == 0 then
    vim.notify("obsidian-para-flow: no notes in " .. options.prompt, vim.log.levels.INFO)
    return
  end
  table.sort(relative_paths)
  ui.select(relative_paths, { prompt = options.prompt .. ": " }, function(choice)
    if choice then
      open_path(vim.fs.joinpath(options.cwd, choice))
    end
  end)
end

local function builtin_grep(_, options)
  if vim.fn.executable("rg") ~= 1 then
    ui.notify_error("ripgrep (`rg`) is required to search note contents")
    return
  end
  ui.input({ prompt = ("Grep %s: "):format(options.prompt) }, function(query)
    if not query or vim.trim(query) == "" then
      return
    end
    local output = vim.fn.systemlist({
      "rg",
      "--vimgrep",
      "--smart-case",
      "--glob",
      "*.md",
      "--",
      query,
      options.cwd,
    })
    if vim.v.shell_error > 1 then
      ui.notify_error("ripgrep failed: " .. table.concat(output, " "))
      return
    end
    if #output == 0 then
      vim.notify("obsidian-para-flow: no matches for " .. query, vim.log.levels.INFO)
      return
    end
    vim.fn.setqflist({}, " ", { title = "Obsidian PARA grep: " .. query, lines = output })
    vim.cmd.copen()
  end)
end

local backends = {
  {
    name = "snacks",
    detect = function()
      local ok, snacks = pcall(require, "snacks")
      if ok and type(snacks) == "table" and snacks.picker then
        return snacks
      end
    end,
    files = function(snacks, options)
      snacks.picker.files({ cwd = options.cwd, ft = "md", title = options.prompt })
    end,
    grep = function(snacks, options)
      snacks.picker.grep({ cwd = options.cwd, glob = "*.md", title = options.prompt })
    end,
  },
  {
    name = "fzf-lua",
    detect = function()
      local ok, fzf = pcall(require, "fzf-lua")
      if ok then
        return fzf
      end
    end,
    files = function(fzf, options)
      fzf.files({
        cwd = options.cwd,
        cmd = table.concat(markdown_files_command, " "),
        prompt = options.prompt .. "> ",
      })
    end,
    grep = function(fzf, options)
      fzf.live_grep({
        cwd = options.cwd,
        rg_opts = "--smart-case --glob '*.md' --column --line-number --no-heading --color=always",
        prompt = options.prompt .. "> ",
      })
    end,
  },
  {
    name = "telescope",
    detect = function()
      local ok, builtin = pcall(require, "telescope.builtin")
      if ok then
        return builtin
      end
    end,
    files = function(builtin, options)
      builtin.find_files({
        cwd = options.cwd,
        find_command = markdown_files_command,
        prompt_title = options.prompt,
      })
    end,
    grep = function(builtin, options)
      builtin.live_grep({
        cwd = options.cwd,
        glob_pattern = "*.md",
        prompt_title = options.prompt,
      })
    end,
  },
  {
    name = "builtin",
    detect = function()
      return true
    end,
    files = builtin_files,
    grep = builtin_grep,
  },
}

local function resolve(cfg)
  local provider = cfg.search.provider
  for _, backend in ipairs(backends) do
    if provider == "auto" or provider == backend.name then
      local handle = backend.detect()
      if handle then
        return backend, handle
      end
      if provider == backend.name then
        break
      end
    end
  end
  local fallback = backends[#backends]
  return fallback, fallback.detect()
end

local labels = {
  inbox = "Inbox",
  projects = "Projects",
  areas = "Areas",
  resources = "Resources",
  archives = "Archives",
}

local function folder_for(cfg, category)
  if not category then
    return nil
  end
  return category == "inbox" and cfg.inbox.folder or cfg.para[category].folder
end

local function run(action, cfg, category)
  local backend, handle = resolve(cfg)
  vault.root(cfg, function(result)
    if not result.ok then
      ui.notify_error(result.message or "Could not resolve the vault path")
      return
    end
    local folder = folder_for(cfg, category)
    backend[action](handle, {
      cfg = cfg,
      category = category,
      folder = folder,
      vault_root = result.root,
      cwd = folder and vim.fs.joinpath(result.root, folder) or result.root,
      prompt = category and labels[category] or cfg.vault,
    })
  end)
end

function M.files(cfg, category)
  run("files", cfg, category)
end

function M.grep(cfg, category)
  run("grep", cfg, category)
end

function M.backend(cfg)
  return (resolve(cfg)).name
end

return M
