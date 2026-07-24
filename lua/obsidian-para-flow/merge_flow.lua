local cli = require("obsidian-para-flow.cli")
local merge = require("obsidian-para-flow.merge")
local merge_transaction = require("obsidian-para-flow.merge_transaction")
local ui = require("obsidian-para-flow.ui")

local M = {}
local current

local select_footer = {
  "[Space] Toggle  [Enter] Continue  [Esc] Cancel",
}
local target_footer = { "[Enter] Keep this note  [Esc] Back" }
local preview_footer = { "[<leader>om] Save merge  [<leader>oq] Cancel" }

local function valid_path(path)
  if
    type(path) ~= "string"
    or path == ""
    or path:sub(1, 1) == "/"
    or path:lower():match("%.md$") == nil
    or path:find("\\", 1, true)
  then
    return false
  end
  for part in path:gmatch("[^/]+") do
    if part == "." or part == ".." then
      return false
    end
  end
  return true
end

local function candidates(paths)
  local result = {}
  local seen = {}
  for _, candidate in ipairs(paths or {}) do
    local path = type(candidate) == "table" and candidate.path or candidate
    if valid_path(path) and not seen[path] then
      seen[path] = true
      table.insert(result, path)
    end
  end
  return result
end

local function has_unsaved_buffer(active, path)
  if not active.vault_root then
    return false
  end
  local function normalized(candidate)
    return vim.uv.fs_realpath(candidate) or vim.fs.normalize(candidate)
  end
  local expected = normalized(vim.fs.joinpath(active.vault_root, path))
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_loaded(buffer)
      and vim.bo[buffer].modified
      and normalized(vim.api.nvim_buf_get_name(buffer)) == expected
    then
      return true
    end
  end
  return false
end

local function set_lines(active, lines, modifiable)
  local buffer = active.view.buffers.body
  vim.bo[buffer].readonly = false
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = modifiable == true
  vim.bo[buffer].readonly = modifiable ~= true
end

local function set_cursor(active)
  local window = active.view.windows.body
  if vim.api.nvim_win_is_valid(window) then
    pcall(vim.api.nvim_win_set_cursor, window, { math.max(1, active.index), 0 })
  end
end

local function render_selection(active)
  local lines = {}
  for _, path in ipairs(active.candidates) do
    local marked = active.marked_lookup[path] and "[x] " or "[ ] "
    table.insert(lines, marked .. path)
  end
  set_lines(active, lines, false)
  active.view:render({
    title = "Merge notes",
    status = { ("Select at least two notes · %d selected"):format(#active.marked) },
    footer = select_footer,
  })
  set_cursor(active)
end

local function render_target(active)
  local lines = {}
  for _, path in ipairs(active.marked) do
    table.insert(lines, path)
  end
  set_lines(active, lines, false)
  active.view:render({
    title = "Keep one note",
    status = { "Choose the path that will contain the merged result" },
    footer = target_footer,
  })
  set_cursor(active)
end

local function clear_mappings(active)
  if not active or not active.view or not vim.api.nvim_buf_is_valid(active.view.buffers.body) then
    return
  end
  for _, lhs in ipairs({ "j", "k", "<Down>", "<Up>", "<Space>", "<CR>", "<Esc>", "q" }) do
    pcall(vim.keymap.del, "n", lhs, { buffer = active.view.buffers.body })
  end
end

local function finish(active, result)
  if current ~= active then
    return
  end
  clear_mappings(active)
  current = nil
  if active.group then
    pcall(vim.api.nvim_del_augroup_by_id, active.group)
    active.group = nil
  end
  active.view:close()
  if active.on_complete then
    active.on_complete(result)
  end
end

local function cancel_preview(active)
  local buffer = active.view.buffers.body
  local function discard()
    finish(active, { status = "canceled" })
  end
  if not vim.bo[buffer].modified then
    discard()
    return
  end
  ui.select({ "Cancel", "Discard preview" }, {
    prompt = "The merge preview has unsaved changes:",
  }, function(choice)
    if current == active and choice == "Discard preview" then
      discard()
    end
  end)
end

local function recovery_message(result)
  local recovery = result.recovery or {}
  local states = {}
  for _, source in ipairs(recovery.sources or {}) do
    table.insert(states, source.path .. "=" .. source.status)
  end
  return ("Merge recovery required. Target: %s (%s). Sources: %s%s"):format(
    recovery.target or "unknown",
    recovery.target_state or "unknown",
    table.concat(states, ", "),
    recovery.rollback_failure and (". Rollback failed: " .. recovery.rollback_failure) or ""
  )
end

local function verify_snapshots(active, paths, index, callback)
  local path = paths[index]
  if not path then
    callback(true)
    return
  end
  if has_unsaved_buffer(active, path) then
    callback(false, "Save or discard the modified Neovim buffer before merging: " .. path)
    return
  end
  cli.read(active.cfg.vault, path, function(result)
    if current ~= active then
      return
    end
    local snapshot = active.snapshots[path]
    if not result.ok or result.stdout ~= snapshot then
      callback(false, result.message or ("The note changed after preview: " .. path))
      return
    end
    verify_snapshots(active, paths, index + 1, callback)
  end)
end

local function apply_merge(active)
  if active.pending then
    return
  end
  active.pending = true
  active.view:render({
    title = "Merge preview",
    status = { "Checking selected notes before saving…" },
    footer = preview_footer,
  })
  verify_snapshots(active, active.ordered_paths, 1, function(ok, message)
    if not ok then
      active.pending = false
      active.view:render({
        title = "Merge preview",
        status = { "Merge not saved · a selected note changed" },
        footer = preview_footer,
      })
      ui.notify_error(message)
      return
    end
    local lines = vim.api.nvim_buf_get_lines(active.view.buffers.body, 0, -1, false)
    local content = table.concat(lines, "\n") .. "\n"
    local sources = vim.tbl_filter(function(path)
      return path ~= active.target
    end, active.ordered_paths)
    merge_transaction.execute(active.cfg.vault, {
      target = active.target,
      sources = sources,
      target_snapshot = active.snapshots[active.target],
      content = content,
    }, function(result)
      if current ~= active then
        return
      end
      active.pending = false
      if result.ok then
        vim.notify(
          ("obsidian-para-flow: merged %d notes into %s"):format(
            #active.ordered_paths,
            active.target
          ),
          vim.log.levels.INFO
        )
        finish(active, {
          status = "merged",
          target = active.target,
          sources = sources,
        })
      elseif result.kind == "rollback" then
        local recovery = recovery_message(result)
        ui.notify_error(recovery)
        finish(active, { status = "recovery", recovery = result.recovery })
      else
        active.view:render({
          title = "Merge preview",
          status = { "Merge failed · target restored" },
          footer = preview_footer,
        })
        ui.notify_error(result.message or "Merge failed and the target was restored")
      end
    end)
  end)
end

local function show_preview(active, content, notes)
  active.mode = "preview"
  active.notes = notes
  active.ordered_paths = vim.tbl_map(function(note)
    return note.path
  end, notes)
  clear_mappings(active)
  local buffer = active.view.buffers.body
  vim.bo[buffer].filetype = "markdown"
  active.view:resize({ width = active.cfg.review.width, height = active.cfg.review.height })
  set_lines(active, vim.split(content:gsub("\n$", ""), "\n", { plain = true }), true)
  vim.bo[buffer].modified = false
  vim.keymap.set("n", "<leader>om", function()
    apply_merge(active)
  end, { buffer = buffer, silent = true, desc = "Obsidian PARA: save multi-note merge" })
  vim.keymap.set("n", "<leader>oq", function()
    cancel_preview(active)
  end, { buffer = buffer, silent = true, desc = "Obsidian PARA: cancel multi-note merge" })
  active.group = vim.api.nvim_create_augroup("ObsidianParaMerge" .. buffer, { clear = true })
  vim.api.nvim_create_autocmd("QuitPre", {
    group = active.group,
    buffer = buffer,
    callback = function()
      if current == active and active.mode == "preview" then
        vim.schedule(function()
          if current == active then
            cancel_preview(active)
          end
        end)
        error("obsidian-para-flow: use <leader>oq to cancel merge preview", 0)
      end
    end,
  })
  active.view:render({
    title = "Merge preview",
    status = { ("Editing %d notes · saving to %s"):format(#notes, active.target) },
    footer = preview_footer,
  })
  vim.api.nvim_set_current_win(active.view.windows.body)
  pcall(vim.api.nvim_win_set_cursor, active.view.windows.body, { 1, 0 })
end

local function load_notes(active, paths, index, notes)
  local path = paths[index]
  if not path then
    active.pending = false
    local content, ordered_or_error = merge.compose({ notes = notes, target = active.target })
    if not content then
      ui.notify_error(ordered_or_error)
      finish(active, { status = "error" })
      return
    end
    show_preview(active, content, ordered_or_error)
    return
  end
  if has_unsaved_buffer(active, path) then
    active.pending = false
    ui.notify_error("Save or discard the modified Neovim buffer before merging: " .. path)
    render_target(active)
    return
  end
  cli.read(active.cfg.vault, path, function(content_result)
    if current ~= active then
      return
    end
    if not content_result.ok then
      active.pending = false
      ui.notify_error(content_result.message or ("Could not read " .. path))
      render_target(active)
      return
    end
    cli.properties(active.cfg.vault, path, function(properties_result)
      if current ~= active then
        return
      end
      if not properties_result.ok then
        active.pending = false
        ui.notify_error(properties_result.message or ("Could not read properties for " .. path))
        render_target(active)
        return
      end
      active.snapshots[path] = content_result.stdout
      table.insert(notes, {
        path = path,
        content = content_result.stdout,
        properties = properties_result.data,
      })
      load_notes(active, paths, index + 1, notes)
    end)
  end)
end

local function choose_target(active)
  if active.pending then
    return
  end
  active.target = active.marked[active.index]
  active.pending = true
  active.view:render({
    title = "Preparing merge",
    status = { "Reading selected notes through Obsidian CLI…" },
    footer = { "Please wait" },
  })
  load_notes(active, active.marked, 1, {})
end

local function install_mappings(active)
  local buffer = active.view.buffers.body
  local options = { buffer = buffer, silent = true, nowait = true }
  local function move(delta)
    local count = active.mode == "target" and #active.marked or #active.candidates
    active.index = math.max(1, math.min(count, active.index + delta))
    set_cursor(active)
  end
  for lhs, delta in pairs({ j = 1, ["<Down>"] = 1, k = -1, ["<Up>"] = -1 }) do
    vim.keymap.set("n", lhs, function()
      move(delta)
    end, options)
  end
  vim.keymap.set("n", "<Space>", function()
    if active.mode ~= "select" then
      return
    end
    local path = active.candidates[active.index]
    if active.marked_lookup[path] then
      active.marked_lookup[path] = nil
      active.marked = vim.tbl_filter(function(candidate)
        return candidate ~= path
      end, active.marked)
    else
      active.marked_lookup[path] = true
      table.insert(active.marked, path)
    end
    render_selection(active)
  end, options)
  vim.keymap.set("n", "<CR>", function()
    if active.mode == "select" then
      if #active.marked < 2 then
        vim.notify("obsidian-para-flow: select at least two notes", vim.log.levels.INFO)
        return
      end
      active.mode = "target"
      active.index = 1
      render_target(active)
    elseif active.mode == "target" then
      choose_target(active)
    end
  end, options)
  local function escape()
    if active.mode == "target" then
      active.mode = "select"
      active.index = 1
      render_selection(active)
    else
      finish(active, { status = "canceled" })
    end
  end
  vim.keymap.set("n", "<Esc>", escape, options)
  vim.keymap.set("n", "q", escape, options)
end

function M.start(cfg, paths, options)
  if current then
    ui.notify_error("A merge workflow is already open")
    return false
  end
  local available = candidates(paths)
  if #available < 2 then
    vim.notify(
      "obsidian-para-flow: the current filtered result must contain at least two notes",
      vim.log.levels.INFO
    )
    return false
  end
  local active = {
    cfg = cfg,
    candidates = available,
    marked = {},
    marked_lookup = {},
    index = 1,
    mode = "select",
    snapshots = {},
    vault_root = options and options.vault_root,
    on_complete = options and options.on_complete,
  }
  local longest = 0
  for _, path in ipairs(available) do
    longest = math.max(longest, vim.fn.strdisplaywidth(path))
  end
  local configured_width = cfg.review.width < 1
      and math.floor((vim.o.columns - 2) * cfg.review.width)
    or cfg.review.width
  local compact_width = math.min(configured_width, math.max(54, longest + 8))
  local compact_height = math.min(18, #available + 2)
  active.view = ui.open_review({
    title = "Merge notes",
    status = { "Select at least two notes" },
    footer = select_footer,
    layout = "float",
    width = compact_width,
    height = compact_height,
    winblend = cfg.review.winblend,
    body_filetype = "obsidian-para-flow-select",
  })
  current = active
  install_mappings(active)
  render_selection(active)
  return true
end

function M._current()
  return current
end

function M._reset()
  if current then
    finish(current, { status = "canceled" })
  end
  current = nil
end

return M
