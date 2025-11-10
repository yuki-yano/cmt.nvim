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

local function fallback_infos(ft)
  local fallback = fallback_from_ft(ft)
  if type(fallback) ~= "table" then
    return nil
  end
  local infos = {}
  local function format_line_prefix(value)
    if type(value) ~= "string" then
      return nil
    end
    return value:match("^(.*)%%s$") or value:gsub("%%s", "")
  end
  local line_info = fallback.line and info_from_commentstring(fallback.line, "fallback-line")
  if line_info then
    local raw_prefix = format_line_prefix(fallback.line)
    if raw_prefix then
      line_info.prefix = raw_prefix
      line_info.mode = "line"
      line_info.suffix = ""
    end
    infos.line = line_info
  end
  if type(fallback.block) == "table" then
    local block_prefix = fallback.block[1]
    local block_suffix = fallback.block[2]
    if block_prefix and block_suffix then
      infos.block = {
        prefix = block_prefix,
        suffix = block_suffix,
        mode = "block",
        source = "fallback-block",
        resolvable = true,
      }
    end
  end
  if next(infos) == nil then
    return nil
  end
  return infos
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

local function resolve_via_ts(ts, bufnr, location, preferred_kind)
  local reason
  if type(ts.calculate_commentstring) == "function" then
    local order = (preferred_kind == "block") and { "__multiline", "__default" } or { "__default", "__multiline" }
    for _, key in ipairs(order) do
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
        reason = "ts-context-invalid-commentstring"
      else
        reason = ok and ("ts-context-empty:" .. key) or ("ts-context-error:" .. tostring(value))
      end
    end
  else
    reason = "ts-context-missing-calculate"
  end

  if type(ts.update_commentstring) ~= "function" then
    return nil, reason or "ts-context-missing-update"
  end

  local ok, err = pcall(function()
    vim.api.nvim_buf_call(bufnr, function()
      ts.update_commentstring({ location = location })
    end)
  end)
  if not ok then
    return nil, "ts-context-update-error:" .. tostring(err)
  end

  local info, option_reason = commentstring_from_option(bufnr, "ts-context:update")
  if info then
    return info
  end
  return nil, option_reason or reason or "ts-context-update-empty"
end

local function build_resolver_context(bufnr)
  local ctx = {
    bufnr = bufnr,
    ft = vim.bo[bufnr].filetype or "",
    ts = nil,
    ts_reason = nil,
    fallbacks = nil,
  }
  local ok, ts = pcall(require, "ts_context_commentstring.internal")
  if ok then
    ctx.ts = ts
  else
    local reason = "ts-context-unavailable"
    if type(ts) == "string" and ts ~= "" then
      reason = reason .. ":" .. ts
    end
    ctx.ts_reason = reason
  end
  ctx.fallbacks = fallback_infos(ctx.ft)
  return ctx
end

local function resolve_commentstring(ctx, location, preferred_kind)
  local requested_kind = preferred_kind == "block" and "block" or "line"
  local reason

  if ctx.ts then
    local info, ts_reason = resolve_via_ts(ctx.ts, ctx.bufnr, location, requested_kind)
    reason = reason or ts_reason
    if info then
      return info
    end
  else
    reason = ctx.ts_reason
  end

  local option_info, option_reason = commentstring_from_option(ctx.bufnr)
  if option_info then
    return option_info
  end
  reason = reason or option_reason

  if ctx.fallbacks then
    local info = ctx.fallbacks[requested_kind] or ctx.fallbacks[requested_kind == "block" and "line" or "block"]
    if info then
      return vim.deepcopy(info)
    end
  end

  return unresolved(reason)
end

function M.batch_get(bufnr, locations, preferred_kind)
  local results = {}
  if type(locations) ~= "table" or vim.tbl_isempty(locations) then
    return results
  end
  local ctx = build_resolver_context(bufnr)
  for _, loc in ipairs(locations) do
    local location = build_location(loc)
    local info = resolve_commentstring(ctx, location, preferred_kind)
    info.line = loc.line
    info.line_index = loc.line_index
    results[#results + 1] = info
  end
  return results
end

function M.resolve_at(bufnr, location, preferred_kind)
  if type(location) ~= "table" then
    return nil
  end
  local ctx = build_resolver_context(bufnr)
  local resolved = resolve_commentstring(ctx, build_location(location), preferred_kind)
  resolved.line = location.line
  resolved.line_index = location.line_index
  return resolved
end

return M
