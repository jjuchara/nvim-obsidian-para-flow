local M = {}

local function split_document(content)
  local lines = vim.split(content or "", "\n", { plain = true })
  if lines[1] ~= "---" then
    return lines
  end
  for index = 2, #lines do
    if lines[index] == "---" then
      local body = {}
      for body_index = index + 1, #lines do
        table.insert(body, lines[body_index])
      end
      return body
    end
  end
  return lines
end

local function trim_blank_edges(lines)
  while lines[1] == "" do
    table.remove(lines, 1)
  end
  while lines[#lines] == "" do
    table.remove(lines)
  end
  return lines
end

local function yaml_value(value)
  if type(value) == "boolean" or type(value) == "number" then
    return tostring(value)
  end
  return vim.json.encode(value):gsub("\\/", "/")
end

local function normalized_tags(value)
  return type(value) == "table" and value or { value }
end

local function merge_properties(notes)
  local merged = vim.deepcopy(notes[1].properties or {})
  local tags = {}
  local seen_tags = {}
  local function append_tags(value)
    if value == nil then
      return
    end
    for _, tag in ipairs(normalized_tags(value)) do
      local key = tostring(tag):gsub("^#", "")
      if key ~= "" and not seen_tags[key] then
        seen_tags[key] = true
        table.insert(tags, tag)
      end
    end
  end
  append_tags(merged.tags)
  for index = 2, #notes do
    for name, value in pairs(notes[index].properties or {}) do
      if name == "tags" then
        append_tags(value)
      elseif
        merged[name] == nil or (type(merged[name]) == "string" and vim.trim(merged[name]) == "")
      then
        merged[name] = vim.deepcopy(value)
      end
    end
  end
  if #tags > 0 then
    merged.tags = tags
  end
  return merged
end

local function title(path)
  return vim.fn.fnamemodify(path, ":t:r")
end

function M.order(notes, target)
  local ordered = {}
  local found
  for _, note in ipairs(notes or {}) do
    if note.path == target then
      found = note
      break
    end
  end
  if not found then
    return nil, "The selected merge target is missing"
  end
  table.insert(ordered, found)
  for _, note in ipairs(notes) do
    if note.path ~= target then
      table.insert(ordered, note)
    end
  end
  return ordered
end

function M.compose(options)
  local notes, order_error = M.order(options.notes, options.target)
  if not notes then
    return nil, order_error
  end
  if #notes < 2 then
    return nil, "Select at least two notes to merge"
  end

  local lines = { "---" }
  local properties = merge_properties(notes)
  local names = vim.tbl_keys(properties)
  table.sort(names)
  for _, name in ipairs(names) do
    table.insert(lines, name .. ": " .. yaml_value(properties[name]))
  end
  table.insert(lines, "---")

  for index, note in ipairs(notes) do
    table.insert(lines, "## " .. title(note.path))
    local body = trim_blank_edges(split_document(note.content))
    if #body > 0 then
      table.insert(lines, "")
      vim.list_extend(lines, body)
    end
    if index < #notes then
      table.insert(lines, "")
      table.insert(lines, "---")
      table.insert(lines, "")
    end
  end
  return table.concat(lines, "\n") .. "\n", notes
end

return M
