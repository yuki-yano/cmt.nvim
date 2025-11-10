local commentstring = require("cmt.commentstring")
local toggler = require("cmt.toggler")

local Service = {}

local function enumerate_locations(start_line, lines)
  local locations = {}
  for idx, text in ipairs(lines) do
    local first = text:find("%S")
    if first then
      locations[#locations + 1] = {
        line = start_line + idx - 1,
        column = first - 1,
        line_index = idx,
      }
    end
  end
  return locations
end

local function fetch_comment_infos(bufnr, lines, preferred_kind, locations)
  if not locations then
    return {}
  end
  local fetched
  if #locations > 0 then
    fetched = commentstring.batch_get(bufnr, locations, preferred_kind or "line")
  end
  fetched = fetched or {}
  local infos = {}
  for idx = 1, #lines do
    infos[idx] = false
  end
  for idx, info in ipairs(fetched) do
    local line_idx = info and info.line_index
    if not line_idx then
      local location = locations[idx]
      line_idx = location and location.line_index
      if info and line_idx then
        info.line_index = line_idx
      end
    end
    if line_idx and infos[line_idx] ~= nil then
      infos[line_idx] = info
    end
  end
  return infos
end

local function fallback_status(infos)
  for _, info in ipairs(infos) do
    if info and info.resolvable == false then
      return true, info.source
    end
  end
  return false
end

local function normalize_policy(policy)
  if policy == "block" or policy == "line" or policy == "first-line" then
    return policy
  end
  return "mixed"
end

local function first_resolved_info(infos)
  for _, info in ipairs(infos) do
    if info and info.resolvable ~= false then
      return info
    end
  end
end

local function build_uniform_infos(template, count)
  if not template then
    return {}
  end
  local infos = {}
  for idx = 1, count do
    infos[idx] = template
  end
  return infos
end

local function resolve_policy_infos(policy, preferred_kind, fetch_fn, line_count)
  if policy == "line" then
    return fetch_fn("line")
  elseif policy == "block" then
    return fetch_fn("block")
  elseif policy == "first-line" then
    local primary_kind = preferred_kind == "block" and "block" or "line"
    local secondary_kind = primary_kind == "block" and "line" or "block"
    local primary = fetch_fn(primary_kind)
    local secondary = fetch_fn(secondary_kind)
    local template = first_resolved_info(primary) or first_resolved_info(secondary)
    if template then
      return build_uniform_infos(template, line_count)
    end
    return primary or secondary or {}
  end
  return fetch_fn(preferred_kind)
end

local function single_line_info(bufnr, line, preferred_kind)
  local text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ""
  local first = text:find("%S")
  if not first then
    return nil
  end
  if type(commentstring.resolve_at) == "function" then
    return commentstring.resolve_at(bufnr, {
      line = line,
      column = first - 1,
      line_index = 1,
    }, preferred_kind or "line")
  end
  local locations = {
    {
      line = line,
      column = first - 1,
      line_index = 1,
    },
  }
  local infos = fetch_comment_infos(bufnr, { text }, preferred_kind or "line", locations)
  return infos[1]
end

local function current_line_info(preferred_kind)
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.fn.line(".")
  return bufnr, line, single_line_info(bufnr, line, preferred_kind or "line")
end

function Service.toggle(preferred_kind, range, mixed_policy)
  preferred_kind = preferred_kind == "block" and "block" or "line"
  range = range or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local start_line = math.max(range.start_line or 1, 1)
  local end_line = math.max(range.end_line or start_line, start_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  if vim.tbl_isempty(lines) then
    return { status = "ok" }
  end

  local policy = normalize_policy(mixed_policy)
  local locations = enumerate_locations(start_line, lines)
  local cache = {}
  local function fetch(kind)
    if not cache[kind] then
      cache[kind] = fetch_comment_infos(bufnr, lines, kind, locations)
    end
    return cache[kind]
  end
  local infos = resolve_policy_infos(policy, preferred_kind, fetch, #lines)

  local needs_fallback, reason = fallback_status(infos)
  if needs_fallback then
    return {
      status = "fallback",
      payload = { mode = "line", reason = reason },
    }
  end

  local result = toggler.toggle_lines(lines, infos, preferred_kind, policy)
  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, result.lines)
  return {
    status = "ok",
    payload = {
      action = result.action,
      start_line = start_line,
      end_line = end_line,
      bufnr = bufnr,
    },
  }
end

function Service.open_comment(direction)
  local bufnr, _, info = current_line_info("line")
  if not info or info.resolvable == false then
    return {
      status = "fallback",
      payload = { mode = "line", reason = info and info.source or "unresolved" },
    }
  end
  local pad_space = vim.g.cmt_eol_insert_pad_space
  local pad = (pad_space ~= false and info.mode == "line") and " " or ""
  local leader = (info.prefix or "") .. pad
  local opener = direction == "above" and "O" or "o"
  vim.api.nvim_feedkeys(opener .. leader, "n", true)
  return { status = "ok" }
end

function Service.info()
  local bufnr, _, info = current_line_info("line")
  local ft = vim.bo[bufnr].filetype or ""
  local source = (info and info.source) or "none"
  local current
  if info and info.resolvable ~= false then
    current = string.format("%s:%s%s", info.mode or "line", info.prefix or "", info.suffix or "")
  else
    current = "unresolved"
  end
  return {
    status = "ok",
    payload = { message = string.format("cmt.nvim ft=%s comment=%s source=%s", ft, current, source) },
  }
end

return Service
