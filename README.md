# cmt.nvim

Tree-sitter aware commenting for Neovim 0.11+. `cmt.nvim` exposes the classic `gc/gcc/gw/gww/gco/gcO` motions as `<Plug>` mappings, but resolves comment leaders per line using Tree-sitter. When commentstring data is missing, it automatically falls back to Neovim's built-in operators so the basic workflow always works.

## Features

- **Tree-sitter aware line/block toggles**: `gc`/`gw` (and their `gcc`/`gww` forms) resolve the correct commentstring per line via `nvim-ts-context-commentstring`, falling back to Neovim's built-in `gc` when data is missing.
- **Visual/operator integrations**: Visual selections, text-objects (`<Plug>(cmt:textobj-line-i/a)`), and operator-pending motions are supported; repeated `gc` respects existing comments.
- **Comment line opening**: `gco` / `gcO` variants insert properly formatted comment leaders (`g:cmt_eol_insert_pad_space` controls extra padding) with Tree-sitter-aware prefixes.
- **Diagnostics & fallbacks**: `:CmtInfo` reports current commentstrings, fallbacks log clearly, and disabled filetypes transparently delegate to stock `gc`.
- **Mixed-mode control**: `g:cmt_mixed_mode_policy` lets you decide how mixed line/block regions are handled (`mixed` per-line, or force `block`/`line` uniformly). Default prefers block for React (`typescriptreact`/`javascriptreact`) and mixed elsewhere.

## Requirements

- Neovim 0.11+
- [vim-denops/denops.vim](https://github.com/vim-denops/denops.vim)
- [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [JoosepAlviste/nvim-ts-context-commentstring](https://github.com/JoosepAlviste/nvim-ts-context-commentstring)

Fallbacks ensure that `gc` always delegates to Neovim's built-in implementation if Tree-sitter or `commentstring` are missing. `gw` reports a descriptive error when block delimiters cannot be resolved.

## Installation (lazy.nvim)

```lua
return {
  {
    "yuki-yano/cmt.nvim",
    version = false,
    dependencies = {
      "vim-denops/denops.vim",
      "nvim-treesitter/nvim-treesitter",
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      vim.keymap.set({ "n", "x" }, "gc", "<Plug>(cmt:line:toggle)")
      vim.keymap.set({ "n", "x" }, "gw", "<Plug>(cmt:block:toggle)")
      vim.keymap.set("n", "gcc", "<Plug>(cmt:line:toggle:current)")
      vim.keymap.set("n", "gww", "<Plug>(cmt:block:toggle:current)")
      vim.keymap.set("n", "gco", "<Plug>(cmt:open-below-comment)")
      vim.keymap.set("n", "gcO", "<Plug>(cmt:open-above-comment)")
    end,
  },
}
```

If some filetypes should bypass cmt.nvim (for different commenting plugins, etc.) set:

```lua
vim.g.cmt_disabled_filetypes = { "csv" }
```

## Usage

- Map `<Plug>(cmt:line:toggle:operator)` / `<Plug>(cmt:block:toggle:operator)` to your preferred keys (default examples above use `gc`/`gw`).
- `gcc`/`gww` are built from `<Plug>(cmt:*:current)` plus the bundled line text-object (`<Plug>(cmt:textobj-line-i)` / `<Plug>(cmt:textobj-line-a)`).
- `gco`/`gcO` are exposed via `<Plug>(cmt:open-*-comment)` and respect Tree-sitter comment leaders.
- `:CmtInfo` prints the active commentstring, Tree-sitter status, and whether fallbacks were triggered.

## Configuration

Global variables exposed by cmt.nvim:

### Mixed Comment Mode Policy

Use `g:cmt_mixed_mode_policy` to control how mixed block/line contexts are resolved when `gc` or `gw` runs.

- Default is `"line"` (line comments win when both modes exist).
- Accepts either a string or a table:
  - String: global policy (`"line"` or `"block"`).
  - Table: per-filetype override. Keys follow Neovim filetype names (e.g. `tsx`, `jsx`, `typescriptreact`). Provide `default` or `*` for fallback.
- Allowed values: `"line"` or `"block"`.

Example (prefer block for TSX/JSX, keep mixed elsewhere):

```lua
vim.g.cmt_mixed_mode_policy = {
  tsx = "block",
  jsx = "block",
  default = "mixed",
}
```

> Tip: For React TypeScript files the filetype is often `typescriptreact`, so use that key if needed. By default TSX (`tsx`) / JSX (`jsx`) benefit most from `"block"` to keep `{/* ... */}` paired.

By default, cmt.nvim sets:

```lua
vim.g.cmt_mixed_mode_policy = {
  typescriptreact = "block",
  javascriptreact = "block",
  default = "mixed",
}
```

So TSX/JSX-like buffers prefer block comments while everything else stays mixed. Override this table if needed.


| Variable | Default | Description |
| --- | --- | --- |
| `g:cmt_block_fallback` | `{}` | Per-filetype `{ line = "// %s", block = { "/*", "*/" } }` fallback map. |
| `g:cmt_disabled_filetypes` | `{}` | Filetypes that should bypass cmt.nvim (`gc` delegates to Neovim, `gw` emits an error). |
| `g:cmt_log_level` | `"warn"` | Controls logging verbosity (`error`, `warn`, `info`, `debug`). |
| `g:cmt_eol_insert_pad_space` | `true` | Adds a space after `gco/gcO` leaders so dot-repeat stays aligned. |
| `g:cmt_mixed_mode_policy` | `"mixed"` | Dict or string controlling how mixed contexts resolve (`"mixed"`, `"block"`, or `"line"`; accepts `{ tsx = "block", default = "mixed" }`). |

## Development

```bash
# run unit tests for core toggling logic
$ deno test denops/cmt/core/line_toggle_test.ts
```

The implementation follows Denops (TypeScript) + Lua bridges, so changes typically involve:

1. Vimscript (`plugin/cmt.vim`) for `<Plug>` glue and operatorfunc wiring
2. Lua (`lua/cmt/ops.lua`, `lua/cmt/commentstring.lua`) for runtime orchestration and Tree-sitter lookups
3. Denops TypeScript (`denops/cmt/...`) for buffer operations and cross-language batching

PRs should follow the TypeScript coding guidelines defined in `tmp/ai/cmt-nvim-requirements-v0.3.md` (arrow functions, `unknownutil` guards, latest `jsr:` deps, etc.).
