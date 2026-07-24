local background = require("obsidian-para-flow.home_background")
local model = require("obsidian-para-flow.home_model")

local M = {}
local namespace = vim.api.nvim_create_namespace("obsidian-para-flow-home")

local categories = { "inbox", "projects", "areas", "resources", "archives" }
local short_labels = {
  inbox = "INBOX",
  projects = "PROJECTS",
  areas = "AREAS",
  resources = "RESOURCES",
  archives = "ARCHIVES",
}

local function source_hl(name)
  local value = vim.api.nvim_get_hl(0, { name = name, link = false })
  return next(value) and value or {}
end

local function mix(left, right, amount)
  if not left then
    return right
  end
  if not right then
    return left
  end
  local function channel(value, shift)
    return math.floor(value / (2 ^ shift)) % 256
  end
  local function blend(shift)
    return math.floor(channel(left, shift) * (1 - amount) + channel(right, shift) * amount + 0.5)
  end
  return blend(16) * 0x10000 + blend(8) * 0x100 + blend(0)
end

local function set_highlights(intensity)
  local normal = source_hl("Normal")
  local popup = source_hl("Pmenu")
  local comment = source_hl("Comment")
  local special = source_hl("Special")
  local identifier = source_hl("Identifier")
  local accent = special.fg or identifier.fg or 0x8b5cf6
  local background_color = normal.bg or popup.bg
  local foreground = normal.fg or popup.fg or 0xd4d4d8
  local surface = popup.bg or background_color

  vim.api.nvim_set_hl(
    0,
    "ObsidianParaHomeNormal",
    { fg = foreground, bg = background_color, default = true }
  )
  vim.api.nvim_set_hl(
    0,
    "ObsidianParaHomeSurface",
    { fg = foreground, bg = surface, default = true }
  )
  vim.api.nvim_set_hl(
    0,
    "ObsidianParaHomeAccent",
    { fg = accent, bg = surface, bold = true, default = true }
  )
  vim.api.nvim_set_hl(0, "ObsidianParaHomeMuted", {
    fg = comment.fg or mix(foreground, background_color, 0.45),
    bg = surface,
    default = true,
  })
  vim.api.nvim_set_hl(0, "ObsidianParaHomeBorder", {
    fg = mix(comment.fg or foreground, accent, 0.25),
    bg = surface,
    default = true,
  })
  vim.api.nvim_set_hl(0, "ObsidianParaHomeSelected", {
    fg = foreground,
    bg = mix(surface or background_color, accent, 0.18),
    bold = true,
    default = true,
  })
  vim.api.nvim_set_hl(0, "ObsidianParaHomeBackground", {
    fg = background_color and mix(background_color, accent, math.max(0.06, intensity))
      or mix(comment.fg or foreground, accent, math.max(0.06, intensity)),
    bg = background_color,
    default = true,
  })
  vim.api.nvim_set_hl(0, "ObsidianParaHomeError", { link = "DiagnosticError", default = true })
  vim.api.nvim_set_hl(0, "ObsidianParaHomeLoading", { link = "Comment", default = true })
end

local function blank_lines(width, height)
  local lines = {}
  for _ = 1, height do
    table.insert(lines, string.rep(" ", width))
  end
  return lines
end

local function truncate(value, width)
  if width <= 0 then
    return ""
  end
  if vim.fn.strdisplaywidth(value) <= width then
    return value
  end
  if width == 1 then
    return "…"
  end
  local result = ""
  for index = 0, vim.fn.strchars(value) - 1 do
    local character = vim.fn.strcharpart(value, index, 1)
    if vim.fn.strdisplaywidth(result .. character .. "…") > width then
      break
    end
    result = result .. character
  end
  return result .. "…"
end

local function put(lines, row, col, value, max_width)
  if row < 1 or row > #lines or col < 1 then
    return
  end
  local line_width = vim.fn.strchars(lines[row])
  if col > line_width then
    return
  end
  local available = math.min(max_width or line_width, line_width - col + 1)
  value = truncate(value, available)
  local length = vim.fn.strchars(value)
  lines[row] = vim.fn.strcharpart(lines[row], 0, col - 1)
    .. value
    .. vim.fn.strcharpart(lines[row], col - 1 + length)
end

local function add_span(spans, row, col, length, group)
  table.insert(spans, {
    row = row,
    col = col,
    length = math.max(0, length),
    group = group,
  })
end

local function box(lines, spans, row, col, width, height, title, active)
  width = math.max(8, width)
  height = math.max(4, height)
  local label = " " .. title .. " "
  local top_fill = math.max(0, width - vim.fn.strdisplaywidth(label) - 2)
  for line = row, row + height - 1 do
    add_span(spans, line, col, width, "ObsidianParaHomeSurface")
  end
  put(lines, row, col, "╭" .. label .. string.rep("─", top_fill) .. "╮", width)
  for line = row + 1, row + height - 2 do
    put(lines, line, col, "│")
    put(lines, line, col + width - 1, "│")
  end
  put(lines, row + height - 1, col, "╰" .. string.rep("─", width - 2) .. "╯", width)
  add_span(spans, row, col, width, active and "ObsidianParaHomeAccent" or "ObsidianParaHomeBorder")
  add_span(spans, row + height - 1, col, width, "ObsidianParaHomeBorder")
  return {
    row = row,
    col = col,
    width = width,
    height = height,
    content_row = row + 1,
    content_col = col + 2,
    content_width = width - 4,
    content_height = height - 2,
  }
end

local function secondary(item)
  local properties = item.properties
  if item.category == "projects" then
    return properties.status or properties.deadline or ""
  elseif item.category == "areas" then
    return item.group ~= "Root" and item.group or ""
  elseif item.category == "resources" then
    return properties.area or "Without area"
  elseif item.category == "archives" then
    return properties.archived or properties.archive_reason or ""
  end
  return ""
end

local function item_text(item, width)
  local detail = tostring(secondary(item) or "")
  if detail == "" or width < 24 then
    return item.name
  end
  local detail_width = math.min(math.floor(width * 0.4), vim.fn.strdisplaywidth(detail))
  local name_width = width - detail_width - 2
  return truncate(item.name, name_width)
    .. string.rep(
      " ",
      math.max(2, width - vim.fn.strdisplaywidth(truncate(item.name, name_width)) - detail_width)
    )
    .. truncate(detail, detail_width)
end

local function section_items(section, limit)
  if section.status ~= "ready" then
    return {}
  end
  local items = {}
  for index = 1, math.min(limit, #section.data.items) do
    table.insert(items, section.data.items[index])
  end
  return items
end

local function render_section(lines, spans, panel, category, section, state, item_rows)
  if section.status == "loading" then
    for index = 0, math.min(2, panel.content_height - 1) do
      put(lines, panel.content_row + index, panel.content_col, "· loading")
      add_span(spans, panel.content_row + index, panel.content_col, 9, "ObsidianParaHomeLoading")
    end
    return
  elseif section.status == "error" then
    put(lines, panel.content_row, panel.content_col, "! " .. section.message, panel.content_width)
    add_span(
      spans,
      panel.content_row,
      panel.content_col,
      panel.content_width,
      "ObsidianParaHomeError"
    )
    return
  end

  local items = section_items(section, math.min(state.preview_limit, panel.content_height))
  if #items == 0 then
    put(lines, panel.content_row, panel.content_col, "No notes")
    add_span(spans, panel.content_row, panel.content_col, 8, "ObsidianParaHomeMuted")
    return
  end
  for index, item in ipairs(items) do
    local row = panel.content_row + index - 1
    local selected = category == state.active_section and index == state.selections[category]
    put(
      lines,
      row,
      panel.content_col,
      (selected and "› " or "  ") .. item_text(item, panel.content_width - 2),
      panel.content_width
    )
    item_rows[category .. ":" .. index] = row
    if selected then
      add_span(spans, row, panel.content_col, panel.content_width, "ObsidianParaHomeSelected")
    end
  end
end

local function panel_layout(width, height, preview_limit, active_section)
  local body_top = 5
  local body_bottom = height - 3
  local body_height = math.max(6, body_bottom - body_top + 1)
  local panels = {}
  if width >= 120 and height >= 26 then
    local gap = 3
    local usable = width - 8
    local inbox_width = math.floor(usable * 0.31)
    local projects_width = usable - inbox_width - gap
    local top_height = math.min(preview_limit + 3, math.floor(body_height * 0.46))
    local bottom_row = body_top + top_height + 1
    local bottom_height = math.max(5, body_bottom - bottom_row + 1)
    panels.inbox = { body_top, 4, inbox_width, top_height }
    panels.projects = { body_top, 4 + inbox_width + gap, projects_width, top_height }
    local bottom_width = math.floor((usable - gap * 2) / 3)
    panels.areas = { bottom_row, 4, bottom_width, bottom_height }
    panels.resources = { bottom_row, 4 + bottom_width + gap, bottom_width, bottom_height }
    panels.archives = {
      bottom_row,
      4 + (bottom_width + gap) * 2,
      usable - bottom_width * 2 - gap * 2,
      bottom_height,
    }
  elseif width >= 80 and height >= 28 then
    local gap = 2
    local usable = width - 6
    local column = math.floor((usable - gap) / 2)
    local row_height = math.max(5, math.floor((body_height - 2) / 3))
    panels.inbox = { body_top, 3, column, row_height }
    panels.projects = { body_top, 3 + column + gap, usable - column - gap, row_height }
    panels.areas = { body_top + row_height + 1, 3, column, row_height }
    panels.resources = {
      body_top + row_height + 1,
      3 + column + gap,
      usable - column - gap,
      row_height,
    }
    panels.archives = {
      body_top + (row_height + 1) * 2,
      3,
      usable,
      math.max(5, body_bottom - body_top - (row_height + 1) * 2 + 1),
    }
  else
    panels[active_section] = { body_top, 2, math.max(20, width - 2), body_height }
  end
  return panels
end

local function render_overview(lines, spans, width, height, state, item_rows)
  local layouts = panel_layout(width, height, state.preview_limit, state.active_section)
  for _, category in ipairs(categories) do
    local layout = layouts[category]
    if layout then
      local section = state.sections[category]
      local count = section.status == "ready" and (" · %d"):format(#section.data.items) or ""
      local panel = box(
        lines,
        spans,
        layout[1],
        layout[2],
        layout[3],
        layout[4],
        short_labels[category] .. count,
        category == state.active_section
      )
      render_section(lines, spans, panel, category, section, state, item_rows)
    end
  end
end

local function detail_lines(item)
  if not item then
    return { "No note selected" }
  end
  local properties = item.properties
  local values = {
    { "Name", item.name },
    { "Path", item.path },
    { "Category", item.category },
    { "Status", properties.status },
    { "Area", properties.area },
    { "Deadline", properties.deadline },
    { "Created", properties.created },
    { "Modified", os.date("%Y-%m-%d %H:%M", item.info.modified or 0) },
    { "Archived", properties.archived },
    { "Reason", properties.archive_reason },
  }
  local result = {}
  for _, pair in ipairs(values) do
    if pair[2] ~= nil and tostring(pair[2]) ~= "" then
      table.insert(result, pair[1] .. ": " .. tostring(pair[2]))
    end
  end
  return result
end

-- While the incremental filter is reading keys the panel title doubles as the
-- prompt, so the trailing bar shows where typing lands.
local function filter_label(state)
  if state.filtering then
    return " · /" .. state.filter .. "▏"
  end
  if state.filter ~= "" then
    return " · /" .. state.filter
  end
  return ""
end

local function render_full(lines, spans, width, height, state, item_rows)
  local category = state.mode
  local section = state.sections[category]
  local top = 5
  local available_height = math.max(6, height - top - 2)
  local list_width = width >= 100 and math.floor((width - 8) * 0.62) or width - 4
  local panel = box(
    lines,
    spans,
    top,
    3,
    list_width,
    available_height,
    short_labels[category] .. filter_label(state),
    true
  )
  if section.status ~= "ready" then
    render_section(lines, spans, panel, category, section, state, item_rows)
    return
  end

  local items = model.grouped(section.data, state.filter)
  local selected = math.max(1, math.min(state.selections[category], math.max(1, #items)))
  local start = math.max(1, selected - panel.content_height + 1)
  local row = panel.content_row
  local last_group
  for index = start, #items do
    local item = items[index]
    if item.group ~= last_group and row <= panel.content_row + panel.content_height - 1 then
      put(lines, row, panel.content_col, item.group, panel.content_width)
      add_span(spans, row, panel.content_col, panel.content_width, "ObsidianParaHomeMuted")
      row = row + 1
      last_group = item.group
    end
    if row > panel.content_row + panel.content_height - 1 then
      break
    end
    local is_selected = index == selected
    put(
      lines,
      row,
      panel.content_col,
      (is_selected and "› " or "  ") .. item_text(item, panel.content_width - 2),
      panel.content_width
    )
    item_rows[category .. ":" .. index] = row
    if is_selected then
      add_span(spans, row, panel.content_col, panel.content_width, "ObsidianParaHomeSelected")
    end
    row = row + 1
  end
  if #items == 0 then
    put(lines, panel.content_row, panel.content_col, "No matching notes")
  end

  if width >= 100 then
    local details_col = list_width + 5
    local details_width = width - details_col - 2
    local details =
      box(lines, spans, top, details_col, details_width, available_height, "DETAILS", false)
    for index, value in ipairs(detail_lines(items[selected])) do
      if index > details.content_height then
        break
      end
      put(lines, details.content_row + index - 1, details.content_col, value, details.content_width)
    end
  end
end

function M.open(options)
  set_highlights(options.background.intensity)
  local origin_window = vim.api.nvim_get_current_win()
  local origin_tab = vim.api.nvim_get_current_tabpage()
  vim.cmd("tabnew")
  local tab = vim.api.nvim_get_current_tabpage()
  local window = vim.api.nvim_get_current_win()
  local buffer = vim.api.nvim_get_current_buf()
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].modifiable = false
  vim.bo[buffer].filetype = "obsidianparahome"
  vim.wo[window].number = false
  vim.wo[window].relativenumber = false
  vim.wo[window].cursorline = false
  vim.wo[window].signcolumn = "no"
  vim.wo[window].foldcolumn = "0"
  vim.wo[window].winhighlight = "Normal:ObsidianParaHomeNormal,EndOfBuffer:ObsidianParaHomeNormal"

  local group = vim.api.nvim_create_augroup("ObsidianParaHome" .. buffer, { clear = true })
  local view = {
    origin_window = origin_window,
    origin_tab = origin_tab,
    tab = tab,
    window = window,
    buffer = buffer,
    group = group,
    options = options,
  }

  function view:is_valid()
    return vim.api.nvim_buf_is_valid(self.buffer)
      and vim.api.nvim_win_is_valid(self.window)
      and vim.api.nvim_tabpage_is_valid(self.tab)
  end

  function view:focus()
    if self:is_valid() then
      vim.api.nvim_set_current_tabpage(self.tab)
      vim.api.nvim_set_current_win(self.window)
    end
  end

  function view:render(state)
    if not self:is_valid() then
      return
    end
    set_highlights(self.options.background.intensity)
    local width = vim.api.nvim_win_get_width(self.window)
    local height = vim.api.nvim_win_get_height(self.window)
    local lines = blank_lines(width, height)
    local spans = {}
    local item_rows = {}
    local fragments, background_error = background.render(self.options.background, {
      width = width,
      height = height,
    })
    for _, fragment in ipairs(fragments) do
      put(lines, fragment.row, fragment.col, fragment.text)
      add_span(
        spans,
        fragment.row,
        fragment.col,
        vim.fn.strchars(fragment.text),
        "ObsidianParaHomeBackground"
      )
    end

    put(lines, 2, 4, "◆ PARA HOME")
    add_span(spans, 2, 4, 11, "ObsidianParaHomeAccent")
    local vault = truncate(state.vault, math.max(0, math.floor(width / 3)))
    put(lines, 2, math.max(4, width - vim.fn.strdisplaywidth(vault) - 3), vault)
    add_span(
      spans,
      2,
      math.max(4, width - vim.fn.strdisplaywidth(vault) - 3),
      vim.fn.strchars(vault),
      "ObsidianParaHomeMuted"
    )
    put(lines, 3, 4, state.mode == "overview" and "Overview" or short_labels[state.mode])
    if background_error then
      put(lines, 3, math.max(4, width - 48), background_error, 44)
      add_span(spans, 3, math.max(4, width - 48), 44, "ObsidianParaHomeError")
    end

    if state.mode == "overview" then
      render_overview(lines, spans, width, height, state, item_rows)
    else
      render_full(lines, spans, width, height, state, item_rows)
    end

    local delete_label = state.pending_delete and "[d] Trashing…" or "[d] Trash"
    local footer = state.mode == "overview"
        and "[n] New  [i] Review  [p/a/r/x] Section  [f] Find  [g] Grep  [Enter] Open  [m] Merge  " .. delete_label .. "  [R] Refresh  [?] Help  [q] Close"
      or "[j/k] Move  [/] Filter  [f] Find  [g] Grep  [Enter] Open  [m] Merge  "
        .. delete_label
        .. "  [Esc] Overview  [R] Refresh  [q] Close"
    put(lines, height, 3, footer, width - 4)
    add_span(
      spans,
      height,
      3,
      math.min(width - 4, vim.fn.strchars(footer)),
      "ObsidianParaHomeMuted"
    )

    vim.bo[self.buffer].modifiable = true
    vim.api.nvim_buf_set_lines(self.buffer, 0, -1, false, lines)
    vim.bo[self.buffer].modifiable = false
    vim.api.nvim_buf_clear_namespace(self.buffer, namespace, 0, -1)
    for _, span in ipairs(spans) do
      if span.length > 0 and span.row >= 1 and span.row <= height then
        local line = lines[span.row]
        local start_column = vim.str_byteindex(line, span.col - 1)
        local end_column = vim.str_byteindex(line, span.col - 1 + span.length)
        vim.api.nvim_buf_add_highlight(
          self.buffer,
          namespace,
          span.group,
          span.row - 1,
          start_column,
          end_column
        )
      end
    end
    local selected = state.active_section .. ":" .. state.selections[state.active_section]
    local selected_row = item_rows[selected]
    if selected_row then
      pcall(vim.api.nvim_win_set_cursor, self.window, { selected_row, 0 })
    end
  end

  function view:close()
    if self.group then
      pcall(vim.api.nvim_del_augroup_by_id, self.group)
      self.group = nil
    end
    if vim.api.nvim_tabpage_is_valid(self.tab) then
      vim.api.nvim_set_current_tabpage(self.tab)
      pcall(vim.cmd, "tabclose")
    end
    if vim.api.nvim_win_is_valid(self.origin_window) then
      pcall(vim.api.nvim_set_current_win, self.origin_window)
    elseif vim.api.nvim_tabpage_is_valid(self.origin_tab) then
      pcall(vim.api.nvim_set_current_tabpage, self.origin_tab)
    end
  end

  vim.api.nvim_create_autocmd({ "VimResized", "ColorScheme" }, {
    group = group,
    callback = function()
      if view:is_valid() and options.on_redraw then
        options.on_redraw()
      end
    end,
  })

  return view
end

return M
