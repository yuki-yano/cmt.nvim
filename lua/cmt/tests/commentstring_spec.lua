local helper = require("vusted.helper")

describe("cmt.commentstring", function()
  local commentstring
  local bufnr

  local function reset_ts_context()
    package.loaded["ts_context_commentstring.internal"] = nil
  end

  before_each(function()
    helper.cleanup()
    helper.cleanup_loaded_modules("cmt")
    reset_ts_context()
    commentstring = require("cmt.commentstring")
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_option(bufnr, "commentstring", "// %s")
    vim.bo[bufnr].filetype = "typescript"
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    helper.cleanup()
    helper.cleanup_loaded_modules("cmt")
    reset_ts_context()
    vim.g.cmt_block_fallback = nil
  end)

  it("prefers ts-context results for each location", function()
    package.loaded["ts_context_commentstring.internal"] = {
      calculate_commentstring = function(opts)
        if opts.location[1] == 0 then
          return "// %s"
        end
        return "/* %s */"
      end,
    }

    local infos = commentstring.batch_get(bufnr, {
      { line = 1, column = 0 },
      { line = 2, column = 4 },
    }, "line")

    assert.equals("line", infos[1].mode)
    assert.equals("//", infos[1].prefix)
    assert.equals("block", infos[2].mode)
    assert.equals("/*", infos[2].prefix)
    assert.equals("*/", infos[2].suffix)
    assert.are.same({ 1, 2 }, { infos[1].line, infos[2].line })
  end)

  it("falls back to filetype configuration when buffer data is missing", function()
    vim.api.nvim_buf_set_option(bufnr, "commentstring", "")
    vim.bo[bufnr].filetype = "astro"
    vim.g.cmt_block_fallback = {
      astro = {
        line = "-- %s",
        block = { "{/*", "*/}" },
      },
    }

    local infos = commentstring.batch_get(bufnr, {
      { line = 10, column = 0 },
    }, "block")

    assert.equals("block", infos[1].mode)
    assert.equals("{/*", infos[1].prefix)
    assert.equals("*/}", infos[1].suffix)
    assert.is_true(infos[1].resolvable)
  end)

  it("marks entries as unresolved when nothing can be resolved", function()
    vim.api.nvim_buf_set_option(bufnr, "commentstring", "")

    local infos = commentstring.batch_get(bufnr, {
      { line = 5, column = 0 },
    }, "line")

    assert.is_false(infos[1].resolvable)
    assert.equals(5, infos[1].line)
    assert.equals("line", infos[1].mode)
    assert.is_truthy(infos[1].source)
  end)
end)
