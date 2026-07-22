local M = {}

local function unicode_available()
  return vim.o.encoding == "utf-8" and vim.fn.strdisplaywidth("◆") == 1
end

local function constellation(context)
  local diamond = context.unicode and "◆" or "*"
  local point = context.unicode and "·" or "."
  local down = context.unicode and "╲" or "\\"
  local up = context.unicode and "╱" or "/"
  local fragments = {}

  if context.width >= 72 and context.height >= 20 then
    local right = math.max(2, context.width - 24)
    fragments = {
      { row = 2, col = right + 7, text = point .. "      " .. diamond },
      { row = 3, col = right + 5, text = down .. " " .. point .. "  " .. up },
      { row = 4, col = right, text = diamond .. "  " .. point .. "       " .. point },
      { row = 5, col = right + 3, text = up .. "       " .. down },
      { row = 6, col = right + 5, text = point .. "   " .. diamond },
      { row = context.height - 5, col = 3, text = point .. "     " .. diamond },
      { row = context.height - 4, col = 5, text = down .. "   " .. up },
      { row = context.height - 3, col = 7, text = point .. "  " .. point },
    }
  elseif context.width >= 40 and context.height >= 12 then
    fragments = {
      { row = 2, col = context.width - 12, text = point .. "  " .. diamond .. "  " .. point },
      { row = context.height - 2, col = 3, text = diamond .. "  " .. point },
    }
  end
  return fragments
end

local function trim_to_width(value, width)
  if vim.fn.strdisplaywidth(value) <= width then
    return value
  end
  local result = ""
  for index = 0, vim.fn.strchars(value) - 1 do
    local character = vim.fn.strcharpart(value, index, 1)
    if vim.fn.strdisplaywidth(result .. character) > width then
      break
    end
    result = result .. character
  end
  return result
end

function M.render(options, context)
  local provider = options.provider
  if provider == false then
    return {}
  end

  context = vim.tbl_extend("force", context, {
    background = vim.o.background,
    colors_name = vim.g.colors_name,
    unicode = unicode_available(),
  })
  local fragments
  if provider == "constellation" then
    fragments = constellation(context)
  else
    local ok, result = pcall(provider, vim.deepcopy(context))
    if not ok then
      return {}, "Custom Home background failed: " .. tostring(result)
    end
    fragments = result
  end
  if type(fragments) ~= "table" then
    return {}, "Custom Home background must return a list of fragments"
  end

  local safe = {}
  for _, fragment in ipairs(fragments) do
    if
      type(fragment) == "table"
      and type(fragment.row) == "number"
      and fragment.row % 1 == 0
      and type(fragment.col) == "number"
      and fragment.col % 1 == 0
      and type(fragment.text) == "string"
      and not fragment.text:find("[\r\n]")
    then
      local row = math.max(1, math.min(context.height, fragment.row))
      local col = math.max(1, math.min(context.width, fragment.col))
      local value = trim_to_width(fragment.text, context.width - col + 1)
      if value ~= "" then
        table.insert(safe, { row = row, col = col, text = value })
      end
    end
  end
  return safe
end

return M
