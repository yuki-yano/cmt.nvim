local commentstring = require("cmt.commentstring")
local toggler = require("cmt.toggler")

local Service = {}

local function enumerate_locations(start_line, lines)
  local locations = {}
  local mapping = {}
  for idx, text in ipairs(lines) do
    local first = text:find("%S")
    if first then
      local column = first - 1
      locations[#locations + 1] = {
        line = start_line + idx - 1,
        column = column,
      }
      mapping[#locations] = idx
    end
  end
  return locations, mapping
end

local function fetch_comment_infos(bufnr, start_line, lines, preferred_kind)
  local locations, mapping = enumerate_locations(start_line, lines)
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
    local line_idx = mapping[idx]
    if line_idx then
      infos[line_idx] = info
    end
  end
  return infos
end

local function needs_fallback(infos)
  for _, info in ipairs(infos) do
    if info and info.resolvable == false then
      return true
    end
  end
  return false
end

local function fallback_reason(infos)
  for _, info in ipairs(infos) do
    if info and info.resolvable == false then
      return info.source
    end
  end
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
  local cache = {}
  local function fetch(kind)
    if not cache[kind] then
      cache[kind] = fetch_comment_infos(bufnr, start_line, lines, kind)
    end
    return cache[kind]
  end
  local infos = resolve_policy_infos(policy, preferred_kind, fetch, #lines)

  if needs_fallback(infos) then
    return {
      status = "fallback",
      payload = { mode = "line", reason = fallback_reason(infos) },
    }
  end

  local result = toggler.toggle_lines(lines, infos, preferred_kind, policy)
  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, result.lines)
  return { status = "ok", payload = { action = result.action } }
end

function Service.open_comment(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.fn.line(".")
  local text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ""
  local infos = fetch_comment_infos(bufnr, line, { text }, "line")
  local info = infos[1]
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
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype or ""
  local line = vim.fn.line(".")
  local text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ""
  local infos = fetch_comment_infos(bufnr, line, { text }, "line")
  local info = infos[1]
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
