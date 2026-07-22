local metadata = require("obsidian-para-flow.metadata")

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

local function first_h1(lines)
  for index, line in ipairs(lines) do
    local title = line:match("^#%s+(.+)$")
    if title then
      return index, vim.trim(title)
    end
  end
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
  if type(value) == "string" then
    return vim.json.encode(value)
  end
  if type(value) == "boolean" or type(value) == "number" then
    return tostring(value)
  end
  return vim.json.encode(value)
end

local function render(metadata_values, target_body, inbox_body)
  local lines = { "---" }
  local names = vim.tbl_keys(metadata_values)
  table.sort(names)
  for _, name in ipairs(names) do
    table.insert(lines, name .. ": " .. yaml_value(metadata_values[name]))
  end
  table.insert(lines, "---")
  vim.list_extend(lines, target_body)
  if #target_body > 0 and #inbox_body > 0 then
    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, "")
  end
  vim.list_extend(lines, inbox_body)
  return table.concat(lines, "\n") .. "\n"
end

local function merge_properties(target, source)
  local merged = vim.deepcopy(target or {})
  for name, value in pairs(source or {}) do
    if name == "tags" then
      local tags = {}
      local seen = {}
      local function append(candidate)
        local values = type(candidate) == "table" and candidate or { candidate }
        for _, tag in ipairs(values) do
          if tag ~= nil then
            local key = tostring(tag):gsub("^#", "")
            if key ~= "" and not seen[key] then
              seen[key] = true
              table.insert(tags, tag)
            end
          end
        end
      end
      append(merged.tags or {})
      append(value)
      if #tags > 0 then
        merged.tags = tags
      end
    elseif
      merged[name] == nil or (type(merged[name]) == "string" and vim.trim(merged[name]) == "")
    then
      merged[name] = vim.deepcopy(value)
    end
  end
  return merged
end

function M.normalize_name(value)
  if type(value) ~= "string" then
    return nil, "Note name must be a string"
  end
  value = vim.trim(value)
  value = value:gsub("%.md$", "")
  if value == "" or value == "." or value == ".." then
    return nil, "Note name cannot be empty, `.` or `..`"
  end
  if value:find("/", 1, true) or value:find("\\", 1, true) then
    return nil, "Note name cannot contain path separators"
  end
  return value .. ".md"
end

function M.compose(options)
  local merged = merge_properties(options.target_properties, options.source_properties)
  local normalized, normalize_error =
    metadata.normalize(options.category, merged, options.context, options.para)
  if not normalized then
    return nil, normalize_error
  end
  if #normalized.missing > 0 then
    return nil, "Missing required metadata: " .. table.concat(normalized.missing, ", ")
  end

  local target_body = trim_blank_edges(split_document(options.target_content))
  local source_body = trim_blank_edges(split_document(options.source_content))
  local _, target_title = first_h1(target_body)
  local source_title_index, source_title = first_h1(source_body)
  if target_title and source_title and target_title == source_title then
    table.remove(source_body, source_title_index)
    trim_blank_edges(source_body)
  end

  return render(normalized.metadata, target_body, source_body)
end

return M
