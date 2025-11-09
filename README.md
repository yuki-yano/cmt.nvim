# cmt.nvim

cmt.nvim is a comment toggling plugin for Neovim 0.11+ powered by Tree-sitter. It keeps the classic `gc`/`gw` motions, but resolves the correct comment leader per line via `nvim-ts-context-commentstring`, falling back to stock `gc` when data is missing so your workflow never breaks.

---

## Highlights

- **Per-line awareness** – `gc`, `gw`, and their `gcc` / `gww` forms inspect Tree-sitter nodes so JSX/TSX, embedded languages, or templates always get the right prefix/suffix.
- **Operator-ready mappings** – `<Plug>` targets exist for operator-pending, visual, and linewise motions, so you can build any keymap on top of cmt.nvim without losing dot-repeat.
- **Smart line opening** – `gco` / `gcO` inject Tree-sitter-aware leaders (with optional padding) and respect mixed comment modes.
- **Mixed-mode control** – `g:cmt_mixed_mode_policy` lets you choose between `mixed`, `first-line`, `line`, or `block` behaviour per filetype. React-style filetypes default to `first-line`, all others to `mixed`.
- **Diagnostics & fallbacks** – `:CmtInfo` shows the active commentstring and source; when Tree-sitter data is missing, cmt.nvim logs and transparently defers to Neovim’s built-in operators.

---

## Requirements

- Neovim 0.11+
- [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [JoosepAlviste/nvim-ts-context-commentstring](https://github.com/JoosepAlviste/nvim-ts-context-commentstring)
- (Development/tests) [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

---

## Installation (lazy.nvim example)

```lua
return {
  {
    "yuki-yano/cmt.nvim",
    version = false,
    dependencies = {
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

Disable specific filetypes when you want Neovim’s stock behaviour or a different commenting plugin:

```lua
vim.g.cmt_disabled_filetypes = { "csv" }
```

---

## Usage at a Glance

| Action | Mapping (example) | Description |
| --- | --- | --- |
| Toggle line comments | `gc` / `gcc` | Operator/linewise toggles using Tree-sitter aware prefixes. |
| Toggle block comments | `gw` / `gww` | Chooses block prefixes/suffixes per line or falls back to Neovim when unresolved. |
| Visual toggles | `gc` in visual mode | Works on rectangular or characterwise selections. |
| Open comment lines | `gco`, `gcO` | Inserts a comment leader (optionally padded) above/below the cursor. |
| Diagnostics | `:CmtInfo` | Shows the resolved commentstring, source, and fallbacks. |

All mappings are defined as `<Plug>` targets under `plugin/cmt.vim`, so feel free to remap to different keys.

---

## Feature Details

### Tree-sitter aware toggles
- Each selected line is sent to `nvim-ts-context-commentstring` to resolve the correct commentstring.
- When Tree-sitter cannot answer, cmt.nvim optionally retries via `ts.update_commentstring` or falls back to the buffer’s `commentstring`.
- If nothing can be resolved, the request gracefully delegates to Neovim’s built-in `gc`.

### Mixed-mode policies
- Mixed selections (line + block comment contexts) often appear in JSX/TSX.
- `g:cmt_mixed_mode_policy` defines how those regions are handled:
  - `"mixed"`: split the selection into segments based on each line’s mode.  
  - `"first-line"`: inspect the first resolved line and apply that mode uniformly.  
  - `"line"` / `"block"`: force a single mode regardless of context.
- Defaults: `typescriptreact` / `javascriptreact` use `"first-line"` so `gw` follows JSX opening lines; everything else remains `"mixed"`.

### Smart open comment (`gco` / `gcO`)
- Uses the same resolution pipeline as toggles.
- Adds an extra space by default (`g:cmt_eol_insert_pad_space = true`) so typing after the leader stays aligned. Set it to `false` to skip padding.

### Fallbacks & logging
- If a filetype is listed in `g:cmt_disabled_filetypes`, cmt.nvim steps aside and lets stock `gc` handle everything.
- Errors (missing Tree-sitter, invalid `commentstring`, etc.) are logged via `vim.notify`. Adjust verbosity with `g:cmt_log_level`.
- `:CmtInfo` reports the current filetype, resolved mode, prefix/suffix, and source (Tree-sitter, fallback, buffer option, etc.).

---

## Configuration Reference

| Variable | Default | Purpose |
| --- | --- | --- |
| `g:cmt_mixed_mode_policy` | `{ typescriptreact = "first-line", javascriptreact = "first-line", default = "mixed" }` | Dict or string controlling mixed-region behaviour (`"mixed"`, `"first-line"`, `"line"`, `"block"`). |
| `g:cmt_block_fallback` | `{}` | Per-filetype fallback commentstrings, e.g. `{ tsx = { line = "// %s", block = { "{/*", "*/}" } } }`. |
| `g:cmt_disabled_filetypes` | `{}` | Filetypes that should bypass cmt.nvim entirely. |
| `g:cmt_eol_insert_pad_space` | `true` | Adds a trailing space when inserting `gco` / `gcO`. |
| `g:cmt_log_level` | `"warn"` | Logging threshold (`"error"`, `"warn"`, `"info"`, `"debug"`). |

Example configuration focusing on React/Next.js buffers:

```lua
vim.g.cmt_mixed_mode_policy = {
  typescriptreact = "first-line", -- keep JSX comments uniform
  javascriptreact = "first-line",
  astro = "block",                -- always block comment in Astro
  default = "mixed",
}

vim.g.cmt_block_fallback = {
  astro = { line = "-- %s", block = { "<!--", "-->" } },
}
```

---

## Troubleshooting

- **Outputs plain `gc` behaviour**: ensure `nvim-ts-context-commentstring` is installed and attached, and the buffer isn’t listed in `g:cmt_disabled_filetypes`.
- **Always falls back to block comments**: Tree-sitter may only expose block modes for the selection. Adjust `g:cmt_mixed_mode_policy` (for example `"line"` or `"first-line"`).
- **`first-line` still block comments in JSX**: make sure you are invoking `gc` for line comments. `gw` is intentionally block-only unless overridden via the policy.
- **Need more detail**: run `:CmtInfo` to see the mode/prefix source or set `g:cmt_log_level = "info"` and check `:messages`.

---

## Development

```bash
# requires plenary.nvim on 'runtimepath'
nvim --headless -u NONE \
  -c "set rtp+=tmp/plenary.nvim" \
  -c "runtime! plugin/plenary.vim" \
  -c "PlenaryBustedDirectory lua/cmt/tests" \
  -c qa
```

Layout overview:

1. `plugin/cmt.vim` – declares `<Plug>` mappings, operatorfunc hooks, defaults.
2. `lua/cmt/ops.lua` – routing layer (visual/operator dispatch, logging, fallbacks).
3. `lua/cmt/service.lua` – buffer edits, commentstring resolution, policy handling.
4. `lua/cmt/toggler.lua` – pure Lua transformations for line/block alignment.
5. `lua/cmt/commentstring.lua` – wrappers around `commentstring` sources and fallbacks.

PRs are welcome—keep code stylua-friendly and include tests (Plenary busted) for behaviour changes.
