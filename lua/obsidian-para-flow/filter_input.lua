local M = {}

local function drop_last_character(query)
  local length = vim.fn.strchars(query)
  if length <= 0 then
    return ""
  end
  return vim.fn.strcharpart(query, 0, length - 1)
end

-- Translates one getcharstr() key into the next query state. Kept free of any
-- side effects so the incremental filter loop stays testable.
function M.apply(query, key)
  query = query or ""
  if type(key) ~= "string" or key == "" then
    return { query = query, action = "continue" }
  end

  if key == "\27" then
    return { query = query, action = "cancel" }
  end
  if key == "\13" or key == "\n" then
    return { query = query, action = "accept" }
  end
  if key == "\8" or key == "\127" or key == "\128kb" then
    return { query = drop_last_character(query), action = "continue" }
  end
  if key == "\21" then
    return { query = "", action = "continue" }
  end
  if key == "\23" then
    return { query = (query:gsub("%s*%S+%s*$", "")), action = "continue" }
  end

  -- Ignore remaining control characters and the K_SPECIAL sequences that
  -- getcharstr() returns for function and arrow keys.
  local first = key:byte(1)
  if first < 32 or first == 128 then
    return { query = query, action = "continue" }
  end
  return { query = query .. key, action = "continue" }
end

return M
