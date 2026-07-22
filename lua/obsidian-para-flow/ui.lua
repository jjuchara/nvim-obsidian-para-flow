local M = {}
local input
local select

local ReviewView = {}
ReviewView.__index = ReviewView

local function scratch_buffer(filetype)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].filetype = filetype or ""
  return buffer
end

local function set_display_lines(buffer, lines)
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
end

local function resolve_size(value, available, minimum)
  local requested = value < 1 and math.floor(available * value) or value
  return math.max(minimum, math.min(requested, available))
end

local function set_window_options(window)
  vim.wo[window].number = false
  vim.wo[window].relativenumber = false
  vim.wo[window].signcolumn = "no"
  vim.wo[window].foldcolumn = "0"
  vim.wo[window].winfixheight = true
  vim.wo[window].wrap = false
end

local function highlight(name)
  local ok, value = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and value or {}
end

local function configure_float_highlights()
  local normal = highlight("Normal")
  local normal_float = highlight("NormalFloat")
  local border = highlight("FloatBorder")
  local chrome = highlight("Pmenu")
  local neutral = highlight("ColorColumn")
  local title = highlight("FloatTitle")
  local background = chrome.bg
    or normal_float.bg
    or neutral.bg
    or normal.bg
    or (vim.o.background == "dark" and 0x000000 or 0xFFFFFF)
  local foreground = normal_float.fg or normal.fg

  vim.api.nvim_set_hl(0, "ObsidianParaReviewNormal", {
    bg = background,
    fg = foreground,
  })
  vim.api.nvim_set_hl(0, "ObsidianParaReviewEndOfBuffer", {
    bg = background,
    fg = background,
  })
  vim.api.nvim_set_hl(0, "ObsidianParaReviewBorder", {
    bg = background,
    fg = border.fg or foreground,
  })
  vim.api.nvim_set_hl(0, "ObsidianParaReviewChrome", {
    bg = chrome.bg or background,
    fg = chrome.fg or foreground,
  })
  vim.api.nvim_set_hl(0, "ObsidianParaReviewTitle", {
    bg = background,
    bold = true,
    fg = title.fg or border.fg or foreground,
  })
end

local function set_float_window_options(window, normal_group, winblend)
  set_window_options(window)
  vim.wo[window].winblend = winblend or 0
  normal_group = normal_group or "ObsidianParaReviewNormal"
  vim.wo[window].winhighlight = table.concat({
    "Normal:" .. normal_group,
    "NormalNC:" .. normal_group,
    "EndOfBuffer:ObsidianParaReviewEndOfBuffer",
    "SignColumn:ObsidianParaReviewNormal",
    "WinBar:ObsidianParaReviewNormal",
    "WinBarNC:ObsidianParaReviewNormal",
    "FloatBorder:ObsidianParaReviewBorder",
  }, ",")
end

local function open_float(buffers, options)
  configure_float_highlights()
  local available_width = vim.o.columns - 2
  local available_height = vim.o.lines - vim.o.cmdheight - 2
  local width = resolve_size(options.width, available_width, 1)
  local height = resolve_size(options.height, available_height, 3)
  local row = math.floor((available_height - height) / 2)
  local column = math.floor((vim.o.columns - width) / 2)
  local horizontal_padding = width >= 10 and 2 or 0
  local content_column = column + horizontal_padding
  local content_width = width - (horizontal_padding * 2)

  local frame_buffer = scratch_buffer()
  local frame = vim.api.nvim_open_win(frame_buffer, false, {
    relative = "editor",
    row = row,
    col = column,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    focusable = false,
    zindex = 50,
    title = " Inbox review ",
    title_pos = "center",
  })

  local function open(buffer, target_row, target_height, focus)
    return vim.api.nvim_open_win(buffer, focus, {
      relative = "editor",
      row = target_row,
      col = content_column,
      width = content_width,
      height = target_height,
      style = "minimal",
      zindex = 51,
    })
  end

  local windows = {
    frame = frame,
    status = open(buffers.status, row, 1, false),
    body = open(buffers.body, row + 1, height - 2, true),
    footer = open(buffers.footer, row + height - 1, 1, false),
  }
  set_float_window_options(windows.frame, nil, options.winblend)
  set_float_window_options(windows.status, "ObsidianParaReviewChrome", options.winblend)
  set_float_window_options(windows.body, nil, options.winblend)
  set_float_window_options(windows.footer, "ObsidianParaReviewChrome", options.winblend)
  return windows, frame_buffer
end

local function open_fullscreen(buffers)
  vim.cmd("tabnew")
  local tabpage = vim.api.nvim_get_current_tabpage()
  local body = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(body, buffers.body)

  vim.cmd("topleft 1new")
  local status = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(status, buffers.status)

  vim.cmd("botright 1new")
  local footer = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(footer, buffers.footer)

  set_window_options(status)
  set_window_options(body)
  set_window_options(footer)
  vim.api.nvim_set_current_win(body)
  return { status = status, body = body, footer = footer }, tabpage
end

function ReviewView:render(model)
  set_display_lines(self.buffers.status, model.status or { "" })
  set_display_lines(self.buffers.footer, model.footer or { "" })
  if self.layout == "float" and vim.api.nvim_win_is_valid(self.windows.frame) then
    local config = vim.api.nvim_win_get_config(self.windows.frame)
    config.title = { { " " .. (model.title or "Inbox review") .. " ", "ObsidianParaReviewTitle" } }
    config.title_pos = "center"
    vim.api.nvim_win_set_config(self.windows.frame, config)
  end
end

function ReviewView:show_compare(target_buffer, inbox_buffer, model)
  if self.mode ~= nil then
    error("obsidian-para-flow: review view already has a temporary mode", 0)
  end
  self.mode = "compare"
  self.compare = {
    target_buffer = target_buffer,
    inbox_buffer = inbox_buffer,
  }
  vim.bo[target_buffer].modifiable = false
  vim.bo[target_buffer].readonly = true
  vim.bo[inbox_buffer].modifiable = false
  vim.bo[inbox_buffer].readonly = true

  vim.api.nvim_win_set_buf(self.windows.body, target_buffer)
  if self.layout == "float" then
    local original = vim.api.nvim_win_get_config(self.windows.body)
    self.compare.original_body_config = original
    local left_width = math.max(1, math.floor((original.width - 1) / 2))
    local right_width = math.max(1, original.width - left_width - 1)
    vim.api.nvim_win_set_config(
      self.windows.body,
      vim.tbl_extend("force", original, {
        width = left_width,
      })
    )
    self.windows.compare_inbox = vim.api.nvim_open_win(inbox_buffer, true, {
      relative = original.relative,
      row = original.row,
      col = original.col + left_width + 1,
      width = right_width,
      height = original.height,
      style = "minimal",
      zindex = original.zindex,
    })
  else
    vim.api.nvim_set_current_win(self.windows.body)
    vim.cmd("vsplit")
    self.windows.compare_inbox = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(self.windows.compare_inbox, inbox_buffer)
  end
  vim.wo[self.windows.body].winbar = " Existing target "
  vim.wo[self.windows.compare_inbox].winbar = " Inbox source "
  if self.layout == "float" then
    set_float_window_options(self.windows.body, nil, self.winblend)
    set_float_window_options(self.windows.compare_inbox, nil, self.winblend)
  else
    set_window_options(self.windows.body)
    set_window_options(self.windows.compare_inbox)
  end
  self:render(model)
end

function ReviewView:show_preview(preview_buffer, model)
  if self.mode ~= "compare" then
    error("obsidian-para-flow: merge preview requires compare mode", 0)
  end
  if self.windows.compare_inbox and vim.api.nvim_win_is_valid(self.windows.compare_inbox) then
    vim.api.nvim_win_close(self.windows.compare_inbox, true)
  end
  self.windows.compare_inbox = nil
  if self.layout == "float" then
    local original = self.compare.original_body_config
    vim.api.nvim_win_set_config(self.windows.body, original)
  end
  vim.wo[self.windows.body].winbar = " Merge Preview "
  self.mode = "preview"
  self.compare.preview_buffer = preview_buffer
  vim.api.nvim_win_set_buf(self.windows.body, preview_buffer)
  vim.api.nvim_set_current_win(self.windows.body)
  self:render(model)
end

function ReviewView:show_compare_again(model)
  if self.mode ~= "preview" then
    return
  end
  local compare = self.compare
  self.mode = nil
  self.compare = nil
  self:show_compare(compare.target_buffer, compare.inbox_buffer, model)
end

function ReviewView:restore_review(body_buffer, model)
  if self.windows.compare_inbox and vim.api.nvim_win_is_valid(self.windows.compare_inbox) then
    vim.api.nvim_win_close(self.windows.compare_inbox, true)
  end
  self.windows.compare_inbox = nil
  if self.layout == "float" and self.compare and self.compare.original_body_config then
    vim.api.nvim_win_set_config(self.windows.body, self.compare.original_body_config)
  end
  vim.wo[self.windows.body].winbar = ""
  vim.bo[body_buffer].modifiable = true
  vim.bo[body_buffer].readonly = false
  vim.api.nvim_win_set_buf(self.windows.body, body_buffer)
  vim.api.nvim_set_current_win(self.windows.body)
  self.mode = nil
  self.compare = nil
  self:render(model)
end

function ReviewView:is_valid()
  return vim.api.nvim_win_is_valid(self.windows.body)
end

function ReviewView:close()
  if self.closed then
    return
  end
  self.closed = true

  if self.windows.compare_inbox and vim.api.nvim_win_is_valid(self.windows.compare_inbox) then
    vim.api.nvim_win_close(self.windows.compare_inbox, true)
  end

  if self.layout == "fullscreen" and vim.api.nvim_tabpage_is_valid(self.tabpage) then
    vim.api.nvim_set_current_tabpage(self.tabpage)
    vim.cmd("tabclose")
  else
    for _, name in ipairs({ "footer", "body", "status", "frame" }) do
      local window = self.windows[name]
      if window and vim.api.nvim_win_is_valid(window) then
        vim.api.nvim_win_close(window, true)
      end
    end
  end

  if self.owns_body and vim.api.nvim_buf_is_valid(self.buffers.body) then
    vim.api.nvim_buf_delete(self.buffers.body, { force = true })
  end
  if self.origin_window and vim.api.nvim_win_is_valid(self.origin_window) then
    vim.api.nvim_set_current_win(self.origin_window)
  end
end

function M.input(options, callback)
  local handler = input or vim.ui.input
  handler(options, callback)
end

function M.select(items, options, callback)
  local handler = select or vim.ui.select
  handler(items, options, callback)
end

function M.notify_error(message)
  vim.notify("obsidian-para-flow: " .. message, vim.log.levels.ERROR)
end

function M.open_review(options)
  options = options or {}
  local layout = options.layout or "float"
  local winblend = options.winblend == nil and 0 or options.winblend
  if layout ~= "float" and layout ~= "fullscreen" then
    error("obsidian-para-flow: review UI layout must be `float` or `fullscreen`", 0)
  end

  local owns_body = options.body_buffer == nil
  local buffers = {
    status = scratch_buffer("obsidian-para-flow-status"),
    body = options.body_buffer or scratch_buffer("markdown"),
    footer = scratch_buffer("obsidian-para-flow-footer"),
  }
  local origin_window = vim.api.nvim_get_current_win()
  local windows, extra
  if layout == "float" then
    windows, extra = open_float(buffers, {
      width = options.width or 0.7,
      height = options.height or 0.7,
      winblend = winblend,
    })
  else
    windows, extra = open_fullscreen(buffers)
  end

  local view = setmetatable({
    layout = layout,
    buffers = buffers,
    windows = windows,
    origin_window = origin_window,
    owns_body = owns_body,
    closed = false,
    winblend = winblend,
  }, ReviewView)
  if layout == "float" then
    view.frame_buffer = extra
  else
    view.tabpage = extra
  end
  view:render(options)
  return view
end

function M._set_input(value)
  input = value
end

function M._set_select(value)
  select = value
end

function M._reset()
  input = nil
  select = nil
end

return M
