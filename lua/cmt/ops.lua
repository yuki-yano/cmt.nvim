local service = require("cmt.service")

local Ops = {}

local state = {
  pending_kind = nil,
}

local level_order = {
  error = 1,
  warn = 2,
  info = 3,
  debug = 4,
}

local function log(level, message)
  local threshold = string.lower(vim.g.cmt_log_level or "warn")
  local current = level_order[level] or 4
  local border = level_order[threshold] or 2
  if current > border then
    return
  end
  vim.notify(message, vim.log.levels[string.upper(level)], { title = "cmt.nvim" })
end

local function is_disabled()
  local ft = vim.bo.filetype or ""
  local disabled = vim.g.cmt_disabled_filetypes
  if type(disabled) ~= "table" then
    return false
  end
  local seen = {}
  for _, name in ipairs(disabled) do
    seen[name] = true
  end
  return seen[ft] == true
end

local function fallback_gc(mode)
  local ok, comment = pcall(require, "vim._comment")
  if not ok or type(comment.operator) ~= "function" then
    return
  end
  local rhs = comment.operator()
  if mode == "current" then
    rhs = rhs .. "_"
  end
  vim.api.nvim_feedkeys(rhs, "n", true)
end

local function resolve_mixed_policy(kind)
  local fallback = kind == "block" and "block" or "mixed"
  local ft = vim.bo.filetype or ""
  local store = vim.g.cmt_mixed_mode_policy
  local value
  if type(store) == "table" then
    value = store[ft] or store.default or store["*"]
  elseif type(store) == "string" then
    value = store
  end
  if type(value) == "string" then
    value = string.lower(value)
  end
  if value == "block" or value == "line" or value == "mixed" or value == "first-line" then
    return value
  end
  return fallback
end

local function format_reason(payload)
  if type(payload) ~= "table" then
    return ""
  end
  local reason = payload.reason or payload.error
  if type(reason) == "string" and reason ~= "" then
    return " (" .. reason .. ")"
  end
  return ""
end

local function dispatch(payload)
  if is_disabled() then
    if payload.preferred_kind == "line" then
      fallback_gc(payload.scope)
    else
      log("error", "cmt.nvim: block toggle disabled for this filetype")
    end
    return ""
  end

  local ok, result = pcall(service.toggle, payload.preferred_kind, payload.range, payload.mode_policy)
  if not ok then
    log("error", "cmt.nvim: toggle request failed (" .. tostring(result) .. ")")
    fallback_gc(payload.scope)
    return ""
  end
  if result.status == "ok" then
    return ""
  elseif result.status == "fallback" then
    log("info", "cmt.nvim: delegating to Neovim gc fallback" .. format_reason(result.payload))
    fallback_gc(result.payload.mode or "line")
  elseif result.status == "error" then
    local message = result.payload and result.payload.message or "cmt.nvim: unknown error"
    log("error", message .. format_reason(result.payload))
  end
  return ""
end

local function visual_range()
  local mode = vim.fn.mode(1)
  local anchor = vim.fn.getpos("v")
  local cursor = vim.fn.getpos(".")
  local start_line = math.min(anchor[2], cursor[2])
  local end_line = math.max(anchor[2], cursor[2])
  return start_line, end_line, mode
end

local function leave_visual_if_needed(mode)
  if type(mode) ~= "string" then
    return
  end
  local ctrl_v = string.char(22)
  if mode:find("v") or mode:find("V") or mode:find(ctrl_v, 1, true) then
    local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
    vim.api.nvim_feedkeys(esc, "n", false)
  end
end

function Ops.operator(kind)
  state.pending_kind = kind
  vim.go.operatorfunc = "v:lua.require'cmt.ops'._operator"
  return "g@"
end

function Ops.operator_expr(kind)
  return Ops.operator(kind)
end

function Ops._operator(type)
  local start_pos = vim.fn.getpos("'[")
  local end_pos = vim.fn.getpos("']")
  dispatch({
    preferred_kind = state.pending_kind or "line",
    mode_policy = resolve_mixed_policy(state.pending_kind or "line"),
    scope = type == "line" and "line" or "operator",
    range = {
      start_line = start_pos[2],
      end_line = end_pos[2],
    },
  })
  state.pending_kind = nil
end

function Ops.visual(kind)
  local start_line, end_line, mode = visual_range()
  leave_visual_if_needed(mode)
  dispatch({
    preferred_kind = kind,
    mode_policy = resolve_mixed_policy(kind),
    scope = "visual",
    range = {
      start_line = start_line,
      end_line = end_line,
    },
  })
end

function Ops.visual_entry(kind)
  Ops.visual(kind)
end

function Ops.current(kind)
  local line = vim.fn.line(".")
  dispatch({
    preferred_kind = kind,
    mode_policy = resolve_mixed_policy(kind),
    scope = "current",
    range = {
      start_line = line,
      end_line = line,
    },
  })
end

function Ops.current_entry(kind)
  Ops.current(kind)
end

function Ops.open(direction)
  if is_disabled() then
    fallback_gc("line")
    return
  end
  local ok, result = pcall(service.open_comment, direction)
  if not ok then
    fallback_gc("line")
    return
  end
  if result.status == "fallback" then
    log("info", "cmt.nvim: gco/gcO fallback to plain open")
    local feed = direction == "below" and "o" or "O"
    vim.api.nvim_feedkeys(feed, "n", true)
    return
  end
  if result.status ~= "ok" and result.payload then
    log("error", result.payload.message or "cmt.nvim: failed to open comment line")
  end
end

function Ops.info()
  local ok, result = pcall(service.info)
  if not ok then
    log("error", "cmt.nvim: failed to fetch info (" .. tostring(result) .. ")")
    return
  end
  if result.status ~= "ok" then
    log("error", "cmt.nvim: info request returned " .. (result.status or "error") .. format_reason(result.payload))
    return
  end
  if result.payload then
    vim.notify(result.payload.message or "cmt.nvim ready", vim.log.levels.INFO, { title = "cmt.nvim" })
  end
end

return Ops
