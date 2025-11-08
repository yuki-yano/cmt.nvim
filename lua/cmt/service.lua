local commentstring = require("cmt.commentstring")
local toggler = require("cmt.toggler")

local Service = {}

local function enumerate_locations(start_line, lines)
  local locations = {}
  for idx, text in ipairs(lines) do
    local first = text:find("%S")
    local column = first and (first - 1) or 0
    locations[idx] = {
      line = start_line + idx - 1,
      column = column,
    }
  end
  return locations
end

local function fetch_comment_infos(bufnr, start_line, lines, preferred_kind)
  local locations = enumerate_locations(start_line, lines)
  local infos = commentstring.batch_get(bufnr, locations, preferred_kind or "line")
  return infos or {}
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
  if policy == "block" or policy == "line" then
    return policy
  end
  return "mixed"
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

  local infos = fetch_comment_infos(bufnr, start_line, lines, preferred_kind)
  if needs_fallback(infos) then
    return {
      status = "fallback",
      payload = { mode = "line", reason = fallback_reason(infos) },
    }
  end

  local policy = normalize_policy(mixed_policy)
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
