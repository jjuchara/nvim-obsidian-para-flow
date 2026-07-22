local metadata = require("obsidian-para-flow.metadata")

local M = {}

local labels = {
  inbox = "Inbox",
  projects = "Projects",
  areas = "Areas",
  resources = "Resources",
  archives = "Archives",
}

local function text(value, fallback)
  if type(value) == "string" and vim.trim(value) ~= "" then
    return vim.trim(value)
  end
  return fallback
end

local function has_tag(properties, expected)
  local tags = properties.tags
  if type(tags) == "string" then
    tags = { tags }
  end
  for _, tag in ipairs(tags or {}) do
    if type(tag) == "string" and tag:gsub("^#", "") == expected then
      return true
    end
  end
  return false
end

local function name_from_path(path)
  local name = path:match("([^/]+)$") or path
  return name:gsub("%.[mM][dD]$", "")
end

local function timestamp(item, property, fallback)
  return metadata.parse_created(item.properties[property]) or item.info[fallback] or 0
end

local function status_rank(status, order)
  for index, expected in ipairs(order) do
    if status == expected then
      return index
    end
  end
  return #order + 1
end

local function archive_group(item, folder)
  local relative = item.path:sub(#folder + 2)
  return relative:match("^([^/]+)/") or "Root"
end

local function area_group(item)
  return text(item.properties.area, "Without area")
end

local function project_group(item)
  return text(item.properties.status, "No status")
end

local function area_group_path(item, folder)
  local relative = item.path:sub(#folder + 2)
  return relative:match("^(.+)/[^/]+$") or "Root"
end

local function eligible(category, item)
  if category == "projects" then
    return has_tag(item.properties, "projects")
  elseif category == "areas" then
    return has_tag(item.properties, "area") and item.properties.listShow == true
  elseif category == "resources" then
    return has_tag(item.properties, "resources")
  end
  return true
end

local function sort_items(category, items, cfg)
  table.sort(items, function(left, right)
    if category == "inbox" then
      local left_created = timestamp(left, "created", "created")
      local right_created = timestamp(right, "created", "created")
      if left_created ~= right_created then
        return left_created < right_created
      end
    elseif category == "projects" then
      local order = cfg.home.projects.status_order
      local left_status = text(left.properties.status, "")
      local right_status = text(right.properties.status, "")
      local left_rank = status_rank(left_status, order)
      local right_rank = status_rank(right_status, order)
      if left_rank ~= right_rank then
        return left_rank < right_rank
      end
      local left_deadline = text(left.properties.deadline, "9999-99-99")
      local right_deadline = text(right.properties.deadline, "9999-99-99")
      if left_deadline ~= right_deadline then
        return left_deadline < right_deadline
      end
    elseif category == "resources" then
      if left.info.modified ~= right.info.modified then
        return left.info.modified > right.info.modified
      end
    elseif category == "archives" then
      local left_archived = timestamp(left, "archived", "modified")
      local right_archived = timestamp(right, "archived", "modified")
      if left_archived ~= right_archived then
        return left_archived > right_archived
      end
    end
    return left.path < right.path
  end)
end

function M.build(category, raw_items, cfg)
  local folder = category == "inbox" and cfg.inbox.folder or cfg.para[category].folder
  local items = {}
  for _, raw in ipairs(raw_items) do
    if eligible(category, raw) then
      local item = vim.deepcopy(raw)
      item.category = category
      item.name = name_from_path(item.path)
      if category == "projects" then
        item.group = project_group(item)
      elseif category == "areas" then
        item.group = area_group_path(item, folder)
      elseif category == "resources" then
        item.group = area_group(item)
      elseif category == "archives" then
        item.group = archive_group(item, folder)
      else
        item.group = "Inbox"
      end
      table.insert(items, item)
    end
  end
  sort_items(category, items, cfg)

  local groups = {}
  local by_name = {}
  for _, item in ipairs(items) do
    if not by_name[item.group] then
      local group = { name = item.group, items = {} }
      by_name[item.group] = group
      table.insert(groups, group)
    end
    table.insert(by_name[item.group].items, item)
  end

  if category == "projects" then
    table.sort(groups, function(left, right)
      local order = cfg.home.projects.status_order
      local left_rank = status_rank(left.name == "No status" and "" or left.name, order)
      local right_rank = status_rank(right.name == "No status" and "" or right.name, order)
      if left_rank == right_rank then
        return left.name < right.name
      end
      return left_rank < right_rank
    end)
  elseif category ~= "inbox" then
    table.sort(groups, function(left, right)
      return left.name < right.name
    end)
  end

  return {
    category = category,
    label = labels[category],
    items = items,
    groups = groups,
  }
end

function M.filter(data, query)
  query = vim.trim(query or ""):lower()
  if query == "" then
    return data.items
  end
  return vim.tbl_filter(function(item)
    return item.name:lower():find(query, 1, true) ~= nil
      or item.path:lower():find(query, 1, true) ~= nil
  end, data.items)
end

function M.grouped(data, query)
  query = vim.trim(query or ""):lower()
  local items = {}
  for _, group in ipairs(data.groups) do
    for _, item in ipairs(group.items) do
      if
        query == ""
        or item.name:lower():find(query, 1, true) ~= nil
        or item.path:lower():find(query, 1, true) ~= nil
      then
        table.insert(items, item)
      end
    end
  end
  return items
end

return M
