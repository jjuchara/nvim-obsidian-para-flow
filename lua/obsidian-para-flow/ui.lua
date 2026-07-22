local M = {}
local input

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

local function open_float(buffers, options)
  local available_width = vim.o.columns - 2
  local available_height = vim.o.lines - vim.o.cmdheight - 2
  local width = resolve_size(options.width, available_width, 1)
  local height = resolve_size(options.height, available_height, 3)
  local row = math.floor((available_height - height) / 2)
  local column = math.floor((vim.o.columns - width) / 2)

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
  })

  local function open(buffer, target_row, target_height, focus)
    return vim.api.nvim_open_win(buffer, focus, {
      relative = "editor",
      row = target_row,
      col = column,
      width = width,
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
  set_window_options(windows.status)
  set_window_options(windows.body)
  set_window_options(windows.footer)
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
end

function ReviewView:is_valid()
  return vim.api.nvim_win_is_valid(self.windows.body)
end

function ReviewView:close()
  if self.closed then
    return
  end
  self.closed = true

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

function M.notify_error(message)
  vim.notify("obsidian-para-flow: " .. message, vim.log.levels.ERROR)
end

function M.open_review(options)
  options = options or {}
  local layout = options.layout or "float"
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
      width = options.width or 0.85,
      height = options.height or 0.85,
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

function M._reset()
  input = nil
end

return M
