local Toggler = {}

local function display_width(value)
  if value == nil or value == "" then
    return 0
  end
  -- strdisplaywidth respects East Asian width similar to original logic
  return vim.fn.strdisplaywidth(value)
end

local function is_blank(line)
  return line == nil or line:match("%S") == nil
end

local function strip_indent(line)
  local indent = line:match("^%s*") or ""
  return indent, line:sub(#indent + 1)
end

local function mode_from_info(info, fallback)
  if type(info) == "table" then
    if info.mode == "block" then
      return "block"
    elseif info.mode == "line" then
      return "line"
    end
  end
  return fallback
end

local function longest_common_indent(indents)
  if #indents == 0 then
    return ""
  end
  local prefix = indents[1]
  for idx = 2, #indents do
    local target = indents[idx]
    local common = {}
    for i = 1, math.min(#prefix, #target) do
      if prefix:sub(i, i) ~= target:sub(i, i) then
        break
      end
      common[#common + 1] = prefix:sub(i, i)
    end
    prefix = table.concat(common)
    if prefix == "" then
      break
    end
  end
  return prefix
end

local function is_line_commented(line, info)
  info = info or {}
  if is_blank(line) then
    return true
  end
  local indent, body = strip_indent(line)
  local target = body:gsub("^%s*", "")
  local prefix = (info.prefix or ""):gsub("%s*$", "")
  return prefix ~= "" and target:sub(1, #prefix) == prefix
end

local function remove_line_comment(line, info)
  info = info or {}
  if is_blank(line) then
    return line or ""
  end
  local indent, body = strip_indent(line)
  local trimmed_prefix = (info.prefix or ""):gsub("%s*$", "")
  local trimmed = body:gsub("^%s*", "")
  if trimmed_prefix == "" or trimmed:sub(1, #trimmed_prefix) ~= trimmed_prefix then
    return line
  end
  local start_idx = body:find(trimmed_prefix, 1, true)
  if not start_idx then
    return line
  end
  local rest = body:sub(start_idx + #trimmed_prefix)
  rest = rest:gsub("^%s", "")
  return indent .. rest
end

local function preprocess_lines(lines)
  local entries = {}
  local indents = {}
  for idx, line in ipairs(lines) do
    local indent, body = strip_indent(line)
    local blank = is_blank(line)
    entries[idx] = {
      indent = indent,
      body = body,
      blank = blank,
      original = line or "",
    }
    if not blank then
      indents[#indents + 1] = indent
    end
  end
  local shared_indent = longest_common_indent(indents)
  for _, entry in ipairs(entries) do
    entry.anchorable = entry.indent:sub(1, #shared_indent) == shared_indent
    local extra = entry.indent:sub(#shared_indent + 1)
    entry.extra_indent = extra
    if entry.blank then
      entry.relative = ""
    else
      entry.relative = entry.body
    end
  end
  return entries, shared_indent
end

local function render_entry(entry, shared_indent, opts)
  opts = opts or {}
  local indent = entry.anchorable and shared_indent or entry.indent
  local extra = entry.extra_indent or ""
  local prefix = opts.prefix or ""
  local body = opts.body or ""
  local pad = opts.pad
  if pad == nil and opts.auto_pad ~= false and prefix ~= "" and body ~= "" then
    pad = " "
  end
  local parts = {
    indent,
    prefix,
    pad or "",
  }
  if entry.anchorable and opts.include_extra ~= false then
    parts[#parts + 1] = extra
  end
  parts[#parts + 1] = body
  parts[#parts + 1] = opts.tail or ""
  parts[#parts + 1] = opts.suffix or ""
  local text = table.concat(parts)
  if opts.trim then
    text = text:gsub("%s+$", "")
  end
  return text
end

local function align_line_comments(entries, infos, shared_indent)
  local primary
  for _, info in ipairs(infos) do
    if info and info.mode == "line" then
      primary = info
      break
    end
  end
  primary = primary or infos[1] or { prefix = "", suffix = "", mode = "line" }
  local output = {}
  for idx, entry in ipairs(entries) do
    if entry.blank then
      output[idx] = entry.original
    else
      local info = infos[idx]
      if not (info and info.mode == "line") then
        info = primary
      end
      local rest = entry.relative or ""
      output[idx] = render_entry(entry, shared_indent, {
        prefix = info.prefix or "",
        body = rest,
      })
    end
  end
  return output
end

local function is_block_commented(line, info)
  info = info or {}
  if is_blank(line) then
    return true
  end
  local trimmed = vim.trim(line)
  local prefix = info.prefix or ""
  local suffix = info.suffix or ""
  return trimmed:sub(1, #prefix) == prefix and trimmed:sub(-#suffix) == suffix
end

local function remove_block_comment(line, info)
  info = info or {}
  if is_blank(line) then
    return line or ""
  end
  local trimmed = vim.trim(line)
  local prefix = info.prefix or ""
  local suffix = info.suffix or ""
  if prefix == "" or suffix == "" then
    return line
  end
  if trimmed:sub(1, #prefix) ~= prefix or trimmed:sub(-#suffix) ~= suffix then
    return line
  end
  local inner = trimmed:sub(#prefix + 1, #trimmed - #suffix)
  inner = inner:gsub("%s+$", "")
  inner = inner:gsub("^%s", "", 1)
  local extra_indent = inner:match("^%s*") or ""
  inner = inner:sub(#extra_indent + 1)
  local indent = line:match("^%s*") or ""
  return indent .. extra_indent .. inner
end

local function add_block_comments(entries, infos, shared_indent)
  local widths = {}
  local max_width = 0
  for idx, entry in ipairs(entries) do
    local body = entry.relative or ""
    local relative_with_extra = (entry.extra_indent or "") .. body
    local width
    if entry.blank then
      width = 0
    elseif entry.anchorable then
      width = display_width(relative_with_extra)
    else
      width = display_width(body)
    end
    widths[idx] = width
    if width > max_width then
      max_width = width
    end
  end
  local output = {}
  for idx, entry in ipairs(entries) do
    if entry.blank then
      output[idx] = entry.original
    else
      local body = entry.relative or ""
      local info = infos[idx]
      local suffix_pad_length = math.max(max_width - (widths[idx] or 0) + 1, 1)
      local suffix_pad = string.rep(" ", suffix_pad_length)
      output[idx] = render_entry(entry, shared_indent, {
        prefix = info.prefix or "",
        body = body,
        tail = suffix_pad,
        suffix = info.suffix or "",
        trim = true,
      })
    end
  end
  return output
end

local function segment_modes(infos)
  local modes = {}
  for idx, info in ipairs(infos) do
    if info and info.mode == "block" then
      modes[idx] = "block"
    else
      modes[idx] = "line"
    end
  end
  return modes
end

local function run_line_mode(lines, infos)
  local default_info = infos[1] or { prefix = "", suffix = "", mode = "line" }
  local already = true
  for idx, line in ipairs(lines) do
    if not is_line_commented(line, infos[idx] or default_info) then
      already = false
      break
    end
  end
  local updated
  if already then
    updated = {}
    for idx, line in ipairs(lines) do
      updated[idx] = remove_line_comment(line, infos[idx] or default_info)
    end
  else
    local entries, shared_indent = preprocess_lines(lines)
    updated = align_line_comments(entries, infos, shared_indent)
  end
  return { lines = updated, already = already }
end

local function run_block_mode(lines, infos)
  local primary
  for _, info in ipairs(infos) do
    if info and info.mode == "block" then
      primary = info
      break
    end
  end
  primary = primary or infos[1] or { prefix = "", suffix = "", mode = "block" }
  local block_infos = {}
  for idx = 1, #infos do
    local info = infos[idx]
    if info and info.mode == "block" then
      block_infos[idx] = info
    else
      block_infos[idx] = primary
    end
  end
  local already = true
  for idx, line in ipairs(lines) do
    if not is_block_commented(line, block_infos[idx]) then
      already = false
      break
    end
  end
  local updated
  if already then
    updated = {}
    for idx, line in ipairs(lines) do
      updated[idx] = remove_block_comment(line, block_infos[idx])
    end
  else
    local entries, shared_indent = preprocess_lines(lines)
    updated = add_block_comments(entries, block_infos, shared_indent)
  end
  return { lines = updated, already = already }
end

local function run_uniform_mode(mode, lines, infos)
  if mode == "block" then
    return run_block_mode(lines, infos)
  end
  return run_line_mode(lines, infos)
end

local function run_mixed_mode(lines, infos)
  local modes = segment_modes(infos)
  local segments = {}
  local start_idx = 1
  local current = modes[1] or "line"
  for idx = 2, #modes do
    if modes[idx] ~= current then
      segments[#segments + 1] = { start = start_idx, finish = idx - 1, mode = current }
      start_idx = idx
      current = modes[idx]
    end
  end
  segments[#segments + 1] = { start = start_idx, finish = #modes, mode = current }

  local output = {}
  vim.list_extend(output, lines)
  local all_already = true
  for _, segment in ipairs(segments) do
    local slice_lines = {}
    local slice_infos = {}
    for idx = segment.start, segment.finish do
      slice_lines[#slice_lines + 1] = lines[idx]
      slice_infos[#slice_infos + 1] = infos[idx]
    end
    local result = run_uniform_mode(segment.mode, slice_lines, slice_infos)
    for idx = 0, #result.lines - 1 do
      output[segment.start + idx] = result.lines[idx + 1]
    end
    all_already = all_already and result.already
  end

  return { lines = output, already = all_already }
end

function Toggler.toggle_lines(lines, infos, preferred, mixed_policy)
  if not lines or #lines == 0 then
    return { lines = lines or {}, action = "comment" }
  end
  infos = infos or {}
  mixed_policy = mixed_policy or "mixed"

  if mixed_policy == "mixed" then
    local result = run_mixed_mode(lines, infos)
    return { lines = result.lines, action = result.already and "uncomment" or "comment" }
  elseif mixed_policy == "first-line" then
    local fallback_mode = preferred == "block" and "block" or "line"
    local target_mode = mode_from_info(infos[1], fallback_mode)
    local result = run_uniform_mode(target_mode, lines, infos)
    return { lines = result.lines, action = result.already and "uncomment" or "comment" }
  end

  local target_mode = mixed_policy == "block" and "block" or "line"
  local result = run_uniform_mode(target_mode, lines, infos)
  return { lines = result.lines, action = result.already and "uncomment" or "comment" }
end

return Toggler
