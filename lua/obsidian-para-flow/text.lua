local M = {}

-- Lua's string.lower only folds ASCII, so a Cyrillic query never matches a
-- Cyrillic note name. vim.fn.tolower folds multibyte text correctly.
function M.fold(value)
  return vim.fn.tolower(value or "")
end

-- Smart case: an uppercase character anywhere in the query makes it case sensitive.
function M.is_case_sensitive(query)
  return M.fold(query) ~= query
end

function M.matches(haystack, query)
  return M.matches_all({ haystack }, query)
end

-- Every whitespace-separated term must appear in at least one of the haystacks.
function M.matches_all(haystacks, query)
  query = vim.trim(query or "")
  if query == "" then
    return true
  end

  local case_sensitive = M.is_case_sensitive(query)
  local candidates = {}
  for _, value in ipairs(haystacks) do
    if type(value) == "string" and value ~= "" then
      table.insert(candidates, case_sensitive and value or M.fold(value))
    end
  end

  for term in query:gmatch("%S+") do
    local found = false
    for _, candidate in ipairs(candidates) do
      if candidate:find(term, 1, true) then
        found = true
        break
      end
    end
    if not found then
      return false
    end
  end
  return true
end

return M
