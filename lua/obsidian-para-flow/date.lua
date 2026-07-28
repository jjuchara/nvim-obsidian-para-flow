local M = {}

local function is_leap_year(year)
  return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

local function days_in_month(year, month)
  local days = { 31, is_leap_year(year) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  return days[month]
end

function M.days_in_month(year, month)
  return days_in_month(year, month)
end

local function components(value)
  if type(value) ~= "string" then
    return nil
  end
  local year, month, day = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  if
    not year
    or year < 1
    or month < 1
    or month > 12
    or day < 1
    or day > days_in_month(year, month)
  then
    return nil
  end
  return year, month, day
end

function M.components(value)
  return components(value)
end

function M.today()
  return os.date("%Y-%m-%d")
end

function M.add_days(value, amount)
  local year, month, day = components(value)
  if not year then
    return nil
  end

  local step = amount < 0 and -1 or 1
  for _ = 1, math.abs(amount) do
    day = day + step
    if day > days_in_month(year, month) then
      day = 1
      month = month + 1
      if month > 12 then
        month = 1
        year = year + 1
      end
    elseif day < 1 then
      month = month - 1
      if month < 1 then
        month = 12
        year = year - 1
      end
      if year < 1 then
        return nil
      end
      day = days_in_month(year, month)
    end
  end
  return ("%04d-%02d-%02d"):format(year, month, day)
end

function M.add_months(value, amount)
  local year, month, day = components(value)
  if not year then
    return nil
  end
  local absolute_month = year * 12 + month - 1 + amount
  local target_year = math.floor(absolute_month / 12)
  local target_month = absolute_month % 12 + 1
  if target_year < 1 then
    return nil
  end
  day = math.min(day, days_in_month(target_year, target_month))
  return ("%04d-%02d-%02d"):format(target_year, target_month, day)
end

function M.format(value, format)
  local year, month, day = components(value)
  if not year then
    return value
  end
  return os.date(format, os.time({ year = year, month = month, day = day, hour = 12 }))
end

return M
