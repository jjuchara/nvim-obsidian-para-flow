local M = {}

local function is_leap_year(year)
  return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

local function valid_date(year, month, day)
  local days = { 31, is_leap_year(year) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  return month >= 1 and month <= 12 and day >= 1 and day <= days[month]
end

local function local_timestamp(year, month, day, hour, minute, second)
  if not valid_date(year, month, day) or hour > 23 or minute > 59 or second > 59 then
    return nil
  end
  local timestamp = os.time({
    year = year,
    month = month,
    day = day,
    hour = hour,
    min = minute,
    sec = second,
    isdst = nil,
  })
  if not timestamp then
    return nil
  end
  local value = os.date("*t", timestamp)
  if
    value.year ~= year
    or value.month ~= month
    or value.day ~= day
    or value.hour ~= hour
    or value.min ~= minute
    or value.sec ~= second
  then
    return nil
  end
  return timestamp
end

-- Howard Hinnant's civil-date conversion, with 1970-01-01 as day zero.
local function days_from_civil(year, month, day)
  year = year - (month <= 2 and 1 or 0)
  local era = math.floor(year / 400)
  local year_of_era = year - era * 400
  local adjusted_month = month + (month > 2 and -3 or 9)
  local day_of_year = math.floor((153 * adjusted_month + 2) / 5) + day - 1
  local day_of_era = year_of_era * 365
    + math.floor(year_of_era / 4)
    - math.floor(year_of_era / 100)
    + day_of_year
  return era * 146097 + day_of_era - 719468
end

function M.parse_created(value)
  if type(value) ~= "string" then
    return nil
  end
  value = vim.trim(value)

  local day, month, year, hour, minute = value:match("^(%d%d)%.(%d%d)%.(%d%d%d%d) (%d%d):(%d%d)$")
  if day then
    return local_timestamp(
      tonumber(year),
      tonumber(month),
      tonumber(day),
      tonumber(hour),
      tonumber(minute),
      0
    )
  end

  local iso_year, iso_month, iso_day, rest = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)(.*)$")
  if not iso_year then
    return nil
  end
  year, month, day = tonumber(iso_year), tonumber(iso_month), tonumber(iso_day)
  if rest == "" then
    return local_timestamp(year, month, day, 0, 0, 0)
  end

  local timezone
  hour, minute, rest = rest:match("^[Tt ](%d%d):(%d%d)(.*)$")
  if not hour then
    return nil
  end
  local second = 0
  local seconds, tail = rest:match("^:(%d%d)(.*)$")
  if seconds then
    second = tonumber(seconds)
    rest = tail
  end
  rest = rest:gsub("^%.%d+", "")
  if rest == "Z" or rest == "z" then
    timezone = 0
  elseif rest ~= "" then
    local sign, offset_hour, offset_minute = rest:match("^([%+%-])(%d%d):?(%d%d)$")
    if not sign or tonumber(offset_hour) > 23 or tonumber(offset_minute) > 59 then
      return nil
    end
    timezone = (tonumber(offset_hour) * 60 + tonumber(offset_minute)) * (sign == "+" and 1 or -1)
  end

  hour, minute = tonumber(hour), tonumber(minute)
  if not valid_date(year, month, day) or hour > 23 or minute > 59 or second > 59 then
    return nil
  end
  if timezone == nil then
    return local_timestamp(year, month, day, hour, minute, second)
  end
  return days_from_civil(year, month, day) * 86400
    + hour * 3600
    + minute * 60
    + second
    - timezone * 60
end

local function has_value(value)
  return value ~= nil and (type(value) ~= "string" or vim.trim(value) ~= "")
end

local function tag_list(value)
  if type(value) == "table" then
    return vim.deepcopy(value)
  end
  if type(value) == "string" and vim.trim(value) ~= "" then
    return { value }
  end
  return {}
end

local function add_tag(metadata, tag)
  local tags = tag_list(metadata.tags)
  for _, existing in ipairs(tags) do
    if existing:gsub("^#", "") == tag then
      return false
    end
  end
  table.insert(tags, tag)
  metadata.tags = tags
  return true
end

local function add_missing(metadata, additions, name, value, value_type)
  if has_value(metadata[name]) or not has_value(value) then
    return
  end
  metadata[name] = value
  table.insert(additions, { name = name, value = vim.deepcopy(value), type = value_type })
end

function M.normalize(category, existing, context, para)
  context = context or {}
  para = para or {}
  local normalized = vim.deepcopy(existing or {})
  local additions = {}
  local missing = {}

  add_missing(normalized, additions, "created", context.created, "datetime")

  local required_tag = ({ projects = "projects", areas = "area", resources = "resources" })[category]
  if required_tag and add_tag(normalized, required_tag) then
    table.insert(additions, { name = "tags", value = vim.deepcopy(normalized.tags), type = "list" })
  end

  if category == "projects" then
    add_missing(normalized, additions, "links", para.projects and para.projects.link, "text")
    add_missing(normalized, additions, "status", "Планируется", "text")
  elseif category == "areas" then
    add_missing(normalized, additions, "links", para.areas and para.areas.link, "text")
    add_missing(normalized, additions, "listShow", true, "checkbox")
  elseif category == "archives" then
    add_missing(normalized, additions, "archived", context.archived, "date")
  elseif category ~= "resources" then
    return nil, ("Unknown PARA category: %s"):format(tostring(category))
  end

  if (category == "projects" or category == "resources") and not has_value(normalized.area) then
    if has_value(context.area) then
      add_missing(normalized, additions, "area", context.area, "text")
    else
      table.insert(missing, "area")
    end
  end
  if category == "archives" and not has_value(normalized.archive_reason) then
    if has_value(context.archive_reason) then
      add_missing(normalized, additions, "archive_reason", context.archive_reason, "text")
    else
      table.insert(missing, "archive_reason")
    end
  end
  if not has_value(normalized.created) then
    table.insert(missing, "created")
  end
  if category == "archives" and not has_value(normalized.archived) then
    table.insert(missing, "archived")
  end

  return {
    metadata = normalized,
    additions = additions,
    missing = missing,
  }
end

function M.operation_plan(path, destination, category, existing, context, para)
  local normalization, error_message = M.normalize(category, existing, context, para)
  if not normalization then
    return nil, error_message
  end

  local compensation = {}
  for index = #normalization.additions, 1, -1 do
    local step = normalization.additions[index]
    local old_value = existing and existing[step.name]
    table.insert(compensation, has_value(old_value) and {
      action = "set",
      name = step.name,
      value = vim.deepcopy(old_value),
      type = step.type,
    } or {
      action = "remove",
      name = step.name,
    })
  end

  return {
    preflight = {
      path = path,
      destination = destination,
      missing = normalization.missing,
    },
    snapshot = vim.deepcopy(existing or {}),
    apply = normalization.additions,
    move = { path = path, destination = destination },
    compensate = compensation,
    metadata = normalization.metadata,
  }
end

return M
