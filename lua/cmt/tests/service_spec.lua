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
    toggler.toggle_lines = function(lines, infos, preferred, policy)
      captured = { infos = infos, preferred = preferred, policy = policy }
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
