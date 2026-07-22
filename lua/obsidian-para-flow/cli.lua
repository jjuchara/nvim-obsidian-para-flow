local M = {}

local default_timeout = 15000
local startup_timeout = 15000
local startup_retry_interval = 250
local executor
local launcher
local defer = vim.defer_fn

local function trim_output(value)
  return (value or ""):gsub("%s+$", "")
end

local function default_executor(argv, options, callback)
  local ok, process = pcall(vim.system, argv, {
    text = true,
    timeout = options.timeout,
  }, function(result)
    vim.schedule(function()
      callback(result)
    end)
  end)
  if not ok then
    callback({ spawn_error = tostring(process) })
    return nil
  end
  return process
end

local function uri_encode(value)
  return (
    value:gsub("([^%w%-._~])", function(character)
      return ("%%%02X"):format(string.byte(character))
    end)
  )
end

local function default_launcher(vault, callback)
  local _, error_message = vim.ui.open("obsidian://open?vault=" .. uri_encode(vault))
  callback(error_message == nil, error_message)
end

local function classify(argv, raw)
  if raw.spawn_error then
    return {
      ok = false,
      kind = "spawn",
      message = raw.spawn_error,
      argv = argv,
    }
  end

  local stdout = trim_output(raw.stdout)
  local stderr = trim_output(raw.stderr)
  local result = {
    ok = raw.code == 0,
    code = raw.code,
    signal = raw.signal,
    stdout = stdout,
    stderr = stderr,
    argv = argv,
  }
  if raw.code == 124 then
    result.ok = false
    result.kind = "timeout"
    result.message = "Obsidian CLI timed out"
  elseif raw.code ~= 0 then
    result.kind = stderr:match("unable to find Obsidian") and "unavailable" or "exit"
    result.message = stderr ~= "" and stderr
      or ("Obsidian CLI exited with code %s"):format(raw.code)
  end
  return result
end

local function argv_for(vault, command, arguments)
  local argv = { "obsidian", "vault=" .. vault, command }
  vim.list_extend(argv, arguments or {})
  return argv
end

function M.run(vault, command, arguments, callback, options)
  local argv = argv_for(vault, command, arguments)
  local run = executor or default_executor
  local run_options = { timeout = (options or {}).timeout or default_timeout }

  local function execute(target_argv, target_options, on_result)
    local ok, handle = pcall(run, target_argv, target_options, function(raw)
      on_result(classify(target_argv, raw))
    end)
    if not ok then
      on_result(classify(target_argv, { spawn_error = tostring(handle) }))
      return nil
    end
    return handle
  end

  local function wait_until_ready(remaining_attempts, last_result)
    if remaining_attempts <= 0 then
      last_result.message = "Obsidian was started but did not become ready before the timeout"
      callback(last_result)
      return
    end
    defer(function()
      local readiness_argv = argv_for(vault, "version")
      execute(readiness_argv, { timeout = 1000 }, function(readiness_result)
        if readiness_result.ok then
          execute(argv, run_options, callback)
        else
          wait_until_ready(remaining_attempts - 1, readiness_result)
        end
      end)
    end, startup_retry_interval)
  end

  return execute(argv, run_options, function(result)
    if result.kind ~= "unavailable" or (options or {}).auto_start == false then
      callback(result)
      return
    end

    local start = launcher or default_launcher
    local ok, launch_error = pcall(start, vault, function(started, error_message)
      if not started then
        result.kind = "launch"
        result.message = error_message or "Could not start Obsidian"
        callback(result)
        return
      end
      wait_until_ready(math.ceil(startup_timeout / startup_retry_interval), result)
    end)
    if not ok then
      result.kind = "launch"
      result.message = tostring(launch_error)
      callback(result)
    end
  end)
end

local function parse_json_result(result)
  if not result.ok then
    return result
  end
  local ok, data = pcall(vim.json.decode, result.stdout)
  if not ok or type(data) ~= "table" then
    result.ok = false
    result.kind = "output"
    result.message = "Obsidian CLI returned invalid JSON"
    return result
  end
  result.data = data
  return result
end

function M.version(vault, callback)
  return M.run(vault, "version", nil, callback)
end

function M.vault_info(vault, field, callback)
  return M.run(vault, "vault", { "info=" .. field }, callback)
end

function M.ensure_vault(vault, callback)
  return M.vault_info(vault, "name", function(result)
    if result.ok and result.stdout ~= vault then
      result.ok = false
      result.kind = "vault"
      result.message = ("Obsidian opened vault `%s`, expected `%s`"):format(result.stdout, vault)
    end
    callback(result)
  end)
end

function M.list_files(vault, folder, callback)
  return M.run(vault, "files", { "folder=" .. folder, "ext=md" }, function(result)
    if result.ok then
      result.data = result.stdout == "" and {} or vim.split(result.stdout, "\n", { plain = true })
    end
    callback(result)
  end)
end

function M.folder_info(vault, folder, callback)
  return M.run(vault, "folder", { "path=" .. folder }, callback)
end

function M.file_info(vault, path, callback)
  return M.run(vault, "file", { "path=" .. path }, function(result)
    if result.ok then
      local data = {}
      for line in result.stdout:gmatch("[^\n]+") do
        local name, value = line:match("^(%S+)%s+(.+)$")
        if name then
          data[name] = (name == "created" or name == "modified" or name == "size")
              and tonumber(value)
            or value
        end
      end
      if type(data.created) ~= "number" then
        result.ok = false
        result.kind = "output"
        result.message = "Obsidian CLI returned file info without a numeric creation time"
      else
        result.data = data
      end
    end
    callback(result)
  end)
end

function M.quickadd(vault, choice, variables, callback)
  local arguments = { "choice=" .. choice }
  for name, value in vim.spairs(variables or {}) do
    table.insert(arguments, "value-" .. name .. "=" .. value)
  end
  return M.run(vault, "quickadd", arguments, function(result)
    result = parse_json_result(result)
    if result.ok and result.data.ok == false then
      result.ok = false
      result.kind = result.data.aborted and "canceled" or "output"
      result.message = result.data.error or "QuickAdd did not complete"
    end
    callback(result)
  end)
end

function M.quickadd_check(vault, choice, callback)
  return M.run(vault, "quickadd:check", { "choice=" .. choice }, function(result)
    callback(parse_json_result(result))
  end)
end

function M.read(vault, path, callback)
  return M.run(vault, "read", { "path=" .. path }, callback)
end

function M.properties(vault, path, callback)
  return M.run(vault, "properties", { "path=" .. path, "format=json" }, function(result)
    callback(parse_json_result(result))
  end)
end

function M.property_set(vault, path, name, value, value_type, callback)
  local arguments = { "path=" .. path, "name=" .. name, "value=" .. value }
  if value_type then
    table.insert(arguments, "type=" .. value_type)
  end
  return M.run(vault, "property:set", arguments, callback)
end

function M.property_remove(vault, path, name, callback)
  return M.run(vault, "property:remove", { "path=" .. path, "name=" .. name }, callback)
end

function M.move(vault, path, destination, callback)
  return M.run(vault, "move", { "path=" .. path, "to=" .. destination }, callback)
end

function M.rename(vault, path, name, callback)
  return M.run(vault, "rename", { "path=" .. path, "name=" .. name }, callback)
end

function M.write(vault, path, content, callback)
  return M.run(vault, "create", { "path=" .. path, "content=" .. content, "overwrite" }, callback)
end

function M.trash(vault, path, callback)
  return M.run(vault, "delete", { "path=" .. path }, callback)
end

function M._set_executor(value)
  executor = value
end

function M._set_launcher(value)
  launcher = value
end

function M._set_defer(value)
  defer = value
end

function M._reset()
  executor = nil
  launcher = nil
  defer = vim.defer_fn
end

return M
