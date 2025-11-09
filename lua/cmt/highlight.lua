local Highlight = {}

local ns = vim.api.nvim_create_namespace("cmt.toggle.highlight")

local active_timer

local function stop_timer()
  if active_timer then
    active_timer:stop()
    active_timer:close()
    active_timer = nil
  end
end

local function read_config()
  local cfg = vim.g.cmt_toggle_highlight
  if type(cfg) ~= "table" then
    cfg = {}
  end
  local groups = cfg.groups
  if type(groups) ~= "table" then
    groups = {}
  end
  local comment_group = groups.comment or cfg.comment_group or "CmtToggleCommented"
  local uncomment_group = groups.uncomment or cfg.uncomment_group or "CmtToggleUncommented"
  return {
    enabled = cfg.enabled ~= false,
    duration = tonumber(cfg.duration) or tonumber(cfg.timeout) or 200,
    priority = tonumber(cfg.priority),
    groups = {
      comment = comment_group,
      uncomment = uncomment_group,
    },
  }
end

local function clear_namespace(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

local function apply_highlight(bufnr, group, start_line, end_line)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for line = start_line, end_line do
    vim.api.nvim_buf_add_highlight(bufnr, ns, group, line, 0, -1)
  end
end

function Highlight.clear(bufnr)
  stop_timer()
  clear_namespace(bufnr or vim.api.nvim_get_current_buf())
end

function Highlight.flash(range, action, bufnr)
  local config = read_config()
  if not config.enabled then
    return
  end
  local groups = config.groups or {}
  local group = groups[(action == "uncomment") and "uncomment" or "comment"]
  if not group or group == "" then
    return
  end
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  range = range or {}
  local start_line = math.max(range.start_line or vim.fn.line("."), 1)
  local end_line = math.max(range.end_line or start_line, start_line)
  local start_idx = start_line - 1
  local end_idx = end_line - 1
  apply_highlight(bufnr, group, start_idx, end_idx)
  stop_timer()
  local handle = vim.loop.new_timer()
  active_timer = handle
  local duration = math.max(config.duration or 200, 10)
  handle:start(duration, 0, function()
    handle:stop()
    handle:close()
    if active_timer == handle then
      active_timer = nil
    end
    vim.schedule(function()
      clear_namespace(bufnr)
    end)
  end)
end

return Highlight
