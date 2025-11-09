local helper = require("vusted.helper")

describe("cmt.ops", function()
  local Ops
  local calls
  local stub_service
  local highlight_calls
  local stub_highlight
  local original_feedkeys
  local fed_keys

  local function reload_ops()
    helper.cleanup()
    helper.cleanup_loaded_modules("cmt")
    package.loaded["cmt.ops"] = nil
    package.loaded["cmt.service"] = stub_service
    package.loaded["cmt.highlight"] = stub_highlight
    Ops = require("cmt.ops")
  end

  before_each(function()
    calls = {}
    highlight_calls = {}
    stub_highlight = {
      flash = function(range, action)
        table.insert(highlight_calls, { range = range, action = action })
      end,
    }
    stub_service = {
      toggle = function(kind, range, policy)
        table.insert(calls, { kind = kind, range = range, policy = policy })
        return { status = "ok" }
      end,
    }
    reload_ops()
    vim.g.cmt_disabled_filetypes = nil
    vim.g.cmt_mixed_mode_policy = nil
    vim.bo.filetype = "lua"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "line1", "line2" })
    vim.fn.cursor(1, 1)
    original_feedkeys = vim.api.nvim_feedkeys
    vim.api.nvim_feedkeys = function(keys)
      fed_keys = keys
    end
    fed_keys = nil
  end)

  after_each(function()
    vim.api.nvim_feedkeys = original_feedkeys
    package.loaded["vim._comment"] = nil
    helper.cleanup()
    helper.cleanup_loaded_modules("cmt")
  end)

  it("honors per-filetype mixed mode overrides", function()
    vim.g.cmt_mixed_mode_policy = {
      lua = "line",
    }
    Ops.current("block")
    assert.equals(1, #calls)
    assert.equals("block", calls[1].kind)
    assert.equals("line", calls[1].policy)
    assert.equals(1, calls[1].range.start_line)
    assert.equals(1, calls[1].range.end_line)
  end)

  it("delegates to fallback gc when filetype is disabled", function()
    vim.g.cmt_disabled_filetypes = { "lua" }
    package.loaded["vim._comment"] = {
      operator = function()
        return "gc"
      end,
    }
    Ops.current("line")
    assert.equals("gc_", fed_keys)
    assert.equals(0, #calls)
  end)

  it("uses pending operator kind when calling service", function()
    vim.fn.setpos("'[", { 0, 1, 1, 0 })
    vim.fn.setpos("']", { 0, 2, 1, 0 })
    Ops.operator("block")
    Ops._operator("line")
    assert.equals(1, #calls)
    assert.equals("block", calls[1].kind)
    assert.equals(1, calls[1].range.start_line)
    assert.equals(2, calls[1].range.end_line)
  end)

  it("flashes the toggled range after a successful operation", function()
    stub_service.toggle = function(kind, range, policy)
      table.insert(calls, { kind = kind, range = range, policy = policy })
      return {
        status = "ok",
        payload = {
          action = "comment",
        },
      }
    end
    reload_ops()
    Ops.current("line")
    assert.equals(1, #highlight_calls)
    assert.equals("comment", highlight_calls[1].action)
    assert.equals(1, highlight_calls[1].range.start_line)
    assert.equals(1, highlight_calls[1].range.end_line)
  end)
end)
