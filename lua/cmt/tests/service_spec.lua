local helper = require("vusted.helper")

local original_commentstring = package.loaded["cmt.commentstring"]
local toggler = require("cmt.toggler")
local original_toggle_lines = toggler.toggle_lines

local function make_info(mode, prefix, suffix)
  return {
    mode = mode,
    prefix = prefix,
    suffix = suffix or "",
    source = "test",
    resolvable = true,
  }
end

local sample_lines = {
  "export const ScreenshotProvider = ({ children }: { children: React.ReactNode }) => {",
  "  const [screenshotWidth, setScreenshotWidth] = useState<number | undefined>(undefined)",
  "  const [isScreenshotMode, setIsScreenshotMode] = useState<boolean>(false)",
  "  return (",
  "    <ScreenshotContext.Provider value={{ screenshotWidth, setScreenshotWidth, isScreenshotMode, setIsScreenshotMode }}>",
  "      {children}",
  "    </ScreenshotContext.Provider>",
  "  )",
  "}",
}

local block_infos = {
  make_info("block", "/*", "*/"),
  make_info("block", "{/*", "*/}"),
  make_info("block", "{/*", "*/}"),
  make_info("block", "{/*", "*/}"),
  make_info("block", "{/*", "*/}"),
  make_info("block", "{/*", "*/}"),
  make_info("block", "{/*", "*/}"),
  make_info("block", "{/*", "*/}"),
  make_info("block", "{/*", "*/}"),
}

local line_infos = {
  make_info("line", "//"),
  make_info("line", "//"),
  make_info("line", "//"),
  make_info("line", "//"),
  make_info("line", "//"),
  make_info("line", "//"),
  make_info("line", "//"),
  make_info("line", "//"),
  make_info("line", "//"),
}

describe("cmt.service first-line policy", function()
  local Service
  local captured
  local bufnr

  local function stub_commentstring()
    package.loaded["cmt.commentstring"] = {
      batch_get = function(_, locations, kind)
        local base = kind == "block" and block_infos or line_infos
        local result = {}
        for idx = 1, #locations do
          local info = vim.deepcopy(base[idx])
          info.line = locations[idx].line
          result[idx] = info
        end
        return result
      end,
    }
  end

  before_each(function()
    stub_commentstring()
    package.loaded["cmt.service"] = nil
    Service = require("cmt.service")
    captured = nil
    toggler.toggle_lines = function(lines, infos, preferred, policy, options)
      captured = { infos = infos, preferred = preferred, policy = policy, options = options }
      return { lines = lines, action = "comment" }
    end
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, sample_lines)
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    toggler.toggle_lines = original_toggle_lines
    package.loaded["cmt.service"] = nil
    if original_commentstring then
      package.loaded["cmt.commentstring"] = original_commentstring
    else
      package.loaded["cmt.commentstring"] = nil
    end
    helper.cleanup()
    helper.cleanup_loaded_modules("cmt")
  end)

  it("uses the first resolved block info for every line when policy=first-line", function()
    local result = Service.toggle("block", { start_line = 1, end_line = #sample_lines }, "first-line")
    assert.equals("ok", result.status)
    assert.is_truthy(captured)
    assert.equals("block", captured.preferred)
    assert.equals("first-line", captured.policy)
    for idx = 1, #sample_lines do
      assert.equals("block", captured.infos[idx].mode, "mode mismatch at idx " .. idx)
      assert.equals("/*", captured.infos[idx].prefix, "prefix mismatch at idx " .. idx)
      assert.equals("*/", captured.infos[idx].suffix, "suffix mismatch at idx " .. idx)
    end
  end)
end)

describe("cmt.service behaviors", function()
  local Service
  local bufnr
  local original_feedkeys
  local fed_keys

  local function with_comment_infos(template)
    package.loaded["cmt.commentstring"] = {
      batch_get = function(_, locations)
        local result = {}
        for idx = 1, #locations do
          local info = vim.deepcopy(template[idx] or template[1])
          info.line = locations[idx].line
          result[idx] = info
        end
        return result
      end,
    }
    package.loaded["cmt.service"] = nil
    Service = require("cmt.service")
  end

  before_each(function()
    helper.cleanup()
    helper.cleanup_loaded_modules("cmt")
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line 1", "line 2" })
    vim.api.nvim_set_current_buf(bufnr)
    original_feedkeys = vim.api.nvim_feedkeys
    vim.api.nvim_feedkeys = function(keys)
      fed_keys = keys
    end
    fed_keys = nil
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    vim.api.nvim_feedkeys = original_feedkeys
    helper.cleanup()
    helper.cleanup_loaded_modules("cmt")
    package.loaded["cmt.service"] = nil
  end)

  it("returns fallback when infos are unresolvable", function()
    with_comment_infos({
      {
        mode = "line",
        prefix = "",
        suffix = "",
        resolvable = false,
        source = "missing",
      },
    })
    local result = Service.toggle("line", { start_line = 1, end_line = 1 }, "mixed")
    assert.equals("fallback", result.status)
    assert.equals("missing", result.payload.reason)
  end)

  it("returns range metadata when toggle succeeds", function()
    with_comment_infos(line_infos)
    local result = Service.toggle("line", { start_line = 1, end_line = 2 }, "mixed")
    assert.equals("ok", result.status)
    assert.equals(1, result.payload.start_line)
    assert.equals(2, result.payload.end_line)
    assert.equals("comment", result.payload.action)
  end)

  it("passes toggle options through to the toggler", function()
    with_comment_infos(line_infos)
    local toggler_module = require("cmt.toggler")
    local original = toggler_module.toggle_lines
    local captured
    toggler_module.toggle_lines = function(lines, infos, preferred, policy, options)
      captured = options
      return original(lines, infos, preferred, policy)
    end

    local result = Service.toggle("line", { start_line = 1, end_line = 2 }, "mixed", {
      include_blank_lines = true,
    })
    assert.equals("ok", result.status)
    assert.is_truthy(captured)
    assert.is_true(captured.include_blank_lines)

    toggler_module.toggle_lines = original
  end)

  it("open_comment injects padding only when configured", function()
    with_comment_infos({
      {
        mode = "line",
        prefix = "//",
        suffix = "",
        resolvable = true,
      },
    })
    vim.g.cmt_eol_insert_pad_space = false
    local ok_result = Service.open_comment("below")
    assert.equals("ok", ok_result.status)
    assert.equals("o//", fed_keys)

    vim.g.cmt_eol_insert_pad_space = true
    Service.open_comment("above")
    assert.equals("O// ", fed_keys)
  end)

  it("info reports current filetype and resolution", function()
    with_comment_infos({
      {
        mode = "block",
        prefix = "/*",
        suffix = "*/",
        resolvable = true,
        source = "ts-context",
      },
    })
    vim.bo[bufnr].filetype = "lua"
    local result = Service.info()
    assert.equals("ok", result.status)
    assert.equals("cmt.nvim ft=lua comment=block:/**/ source=ts-context", result.payload.message)
  end)
end)
