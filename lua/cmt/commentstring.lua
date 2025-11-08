local M = {}

local function split_commentstring(value)
  if type(value) ~= "string" then
    return nil, nil
  end
  local prefix, suffix = value:match("^(.*)%%s(.*)$")
  if not prefix then
    return nil, nil
  end
  prefix = prefix:gsub("%s*$", "")
  suffix = suffix:gsub("^%s*", "")
  return prefix, suffix
end

local function info_from_commentstring(value, source)
  local prefix, suffix = split_commentstring(value)
  if not prefix then
    return nil
  end
  local mode = (#suffix > 0) and "block" or "line"
  return {
    prefix = prefix,
    suffix = suffix,
    mode = mode,
    source = source,
    resolvable = true,
  }
end

local function fallback_from_ft(ft)
  local store = vim.g.cmt_block_fallback
  if type(store) ~= "table" then
    return nil
  end
  return store[ft]
end

local function format_line_fallback(value)
  if type(value) ~= "string" then
    return nil
  end
  local prefix = value:match("^(.*)%%s$") or value:gsub("%%s", "")
  return prefix
end

local function fallback_info(ft, preferred_kind)
  local fallback = fallback_from_ft(ft)
  if not fallback then
    return nil
  end
  local function line_info()
    local line_value = fallback.line and format_line_fallback(fallback.line)
    if line_value ~= nil then
      return {
        prefix = line_value,
        suffix = "",
        mode = "line",
        source = "fallback-line",
        resolvable = true,
      }
    end
  end
  local function block_info()
    if type(fallback.block) == "table" then
      local block_prefix = fallback.block[1]
      local block_suffix = fallback.block[2]
      if block_prefix and block_suffix then
        return {
          prefix = block_prefix,
          suffix = block_suffix,
          mode = "block",
          source = "fallback-block",
          resolvable = true,
        }
      end
    end
  end
  local order = preferred_kind == "block" and { block_info, line_info } or { line_info, block_info }
  for _, fn_get in ipairs(order) do
    local info = fn_get()
    if info then
      return info
    end
  end
  return nil
end

local function unresolved(reason)
  return {
    prefix = "",
    suffix = "",
    mode = "line",
    source = reason or "unresolved",
    resolvable = false,
  }
end

local function commentstring_from_option(bufnr, source)
  local ok, value = pcall(vim.api.nvim_buf_get_option, bufnr, "commentstring")
  if not ok then
    return nil, "buffer-commentstring-error:" .. tostring(value)
  end
  if type(value) ~= "string" or value == "" then
    return nil, "buffer-commentstring-empty"
  end
  local info = info_from_commentstring(value, source or "buffer-commentstring")
  if info then
    return info
  end
  return nil, "buffer-commentstring-invalid"
end

local function build_location(loc)
  local row = math.max((loc.line or 1) - 1, 0)
  local col = math.max(loc.column or 0, 0)
  return { row, col }
end

local function try_ts_calculate(ts, bufnr, location, preferred_kind)
  if type(ts.calculate_commentstring) ~= "function" then
    return nil, "ts-context-missing-calculate"
  end
  local last_reason
  local function attempt(key)
    local ok, value = pcall(ts.calculate_commentstring, {
      key = key,
      location = location,
      buf = bufnr,
    })
    if ok and type(value) == "string" and value ~= "" then
      local info = info_from_commentstring(value, "ts-context:" .. key)
      if info then
        return info
      end
      last_reason = "ts-context-invalid-commentstring"
      return nil
    end
    if not ok then
      last_reason = "ts-context-error:" .. tostring(value)
      return nil
    end
    last_reason = "ts-context-empty:" .. key
    return nil
  end
  local order
  if preferred_kind == "block" then
    order = { "__multiline", "__default" }
  else
    order = { "__default", "__multiline" }
  end
  for _, key in ipairs(order) do
    local info = attempt(key)
    if info then
      return info
    end
  end
  return nil, last_reason or "ts-context-empty"
end

local function try_ts_update(ts, bufnr, location)
  if type(ts.update_commentstring) ~= "function" then
    return nil, "ts-context-missing-update"
  end
  local ok, err = pcall(function()
    vim.api.nvim_buf_call(bufnr, function()
      ts.update_commentstring({ location = location })
    end)
  end)
  if not ok then
    return nil, "ts-context-update-error:" .. tostring(err)
  end
  local info, reason = commentstring_from_option(bufnr, "ts-context:update")
  if info then
    return info
  end
  return nil, reason or "ts-context-update-empty"
end

local function resolve_commentstring(bufnr, location, preferred_kind)
  local requested_kind = preferred_kind == "block" and "block" or "line"
  local ft = vim.bo[bufnr].filetype or ""
  local reason

  local ok, ts = pcall(require, "ts_context_commentstring.internal")
  if ok then
    local info, ts_reason = try_ts_calculate(ts, bufnr, location, requested_kind)
    reason = reason or ts_reason
    if info then
      return info
    end
    local updated, update_reason = try_ts_update(ts, bufnr, location)
    reason = reason or update_reason
    if updated then
      return updated
    end
  else
    reason = "ts-context-unavailable"
    if type(ts) == "string" and ts ~= "" then
      reason = reason .. ":" .. ts
    end
  end

  local option_info, option_reason = commentstring_from_option(bufnr)
  if option_info then
    return option_info
  end
  reason = reason or option_reason

  local fallback = fallback_info(ft, requested_kind)
  if fallback then
    return fallback
  end

  return unresolved(reason)
end

function M.batch_get(bufnr, locations, preferred_kind)
  local results = {}
  for _, loc in ipairs(locations) do
    local location = build_location(loc)
    results[#results + 1] = resolve_commentstring(bufnr, location, preferred_kind)
    results[#results].line = loc.line
  end
  return results
end

return M
