# cmt.nvim

cmt.nvim is a comment toggling plugin for Neovim 0.11+ powered by Tree-sitter. It keeps the classic `gc`/`gw` motions, but resolves the correct comment leader per line via `nvim-ts-context-commentstring`, falling back to stock `gc` when data is missing so your workflow never breaks.

---

## Highlights

- **Per-line awareness** – `gc`, `gw`, and their `gcc` / `gww` forms inspect Tree-sitter nodes so JSX/TSX, embedded languages, or templates always get the right prefix/suffix.
- **Operator-ready mappings** – `<Plug>` targets exist for operator-pending, visual, and linewise motions, so you can build any keymap on top of cmt.nvim without losing dot-repeat.
- **Smart line opening** – `gco` / `gcO` inject Tree-sitter-aware leaders (with optional padding) and respect mixed comment modes.
- **Mixed-mode control** – `g:cmt_mixed_mode_policy` lets you choose between `mixed`, `first-line`, `line`, or `block` behaviour per filetype. React-style filetypes default to `first-line`, all others to `mixed`.
- **Transient flash** – whichever lines were just toggled briefly highlight so you can confirm the affected span even when the cursor stays put.
- **Diagnostics & fallbacks** – `:CmtInfo` shows the active commentstring and source; when Tree-sitter data is missing, cmt.nvim logs and transparently defers to Neovim’s built-in operators.

---

## Requirements

- Neovim 0.11+
- [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [JoosepAlviste/nvim-ts-context-commentstring](https://github.com/JoosepAlviste/nvim-ts-context-commentstring)
- (Development/tests) [notomo/vusted](https://github.com/notomo/vusted) (`luarocks --lua-version=5.1 install vusted`)

---

## Installation (lazy.nvim example)

```lua
return {
  {
    "yuki-yano/cmt.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    keys = {
      { 'gc', '<Plug>(cmt:line:toggle)', mode = { 'n', 'x' } },
      { 'gw', '<Plug>(cmt:block:toggle)', mode = { 'n', 'x' } },
      { 'gC', '<Plug>(cmt:line:toggle:with-blank)', mode = { 'n', 'x' } },
      { 'gW', '<Plug>(cmt:block:toggle:with-blank)', mode = { 'n', 'x' } },
      { 'gcc', '<Plug>(cmt:line:toggle:current)', mode = 'n' },
      { 'gCC', '<Plug>(cmt:line:toggle:with-blank:current)', mode = 'n' },
      { 'gww', '<Plug>(cmt:block:toggle:current)', mode = 'n' },
      { 'gWW', '<Plug>(cmt:block:toggle:with-blank:current)', mode = 'n' },
      { 'gco', '<Plug>(cmt:open-below-comment)', mode = 'n' },
      { 'gcO', '<Plug>(cmt:open-above-comment)', mode = 'n' },
    },
  },
}
```

Disable specific filetypes when you want Neovim’s stock behaviour or a different commenting plugin:

```lua
vim.g.cmt_disabled_filetypes = { "csv" }
```

---

## Usage at a Glance

| Action                | Mapping (example)   | Description                                                                                |
| --------------------- | ------------------- | ------------------------------------------------------------------------------------------ |
| Toggle line comments  | `gc` / `gcc`        | Operator/linewise toggles using Tree-sitter aware prefixes.                                |
| Toggle block comments | `gw` / `gww`        | Chooses block prefixes/suffixes per line or falls back to Neovim when unresolved.          |
| Include blank lines   | `gC` / `gW`         | Uses dedicated `<Plug>` targets that comment blank lines (`//` or `/* */`) alongside code. |
| Visual toggles        | `gc` in visual mode | Works on rectangular or characterwise selections.                                          |
| Open comment lines    | `gco`, `gcO`        | Inserts a comment leader (optionally padded) above/below the cursor.                       |
| Diagnostics           | `:CmtInfo`          | Shows the resolved commentstring, source, and fallbacks.                                   |

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

### Commenting blank lines

- Use `<Plug>(cmt:line:toggle:with-blank)` / `<Plug>(cmt:block:toggle:with-blank)` (mapped to `gC`/`gW` above) when you also want blank lines to be commented.
- Line comments insert only the prefix (e.g. `//`) while block comments emit a literal `/* */` spacer to keep regions readable.
- Operator, visual, and current-line variants exist so you can keep parity with the default mappings.

### Smart open comment (`gco` / `gcO`)

- Uses the same resolution pipeline as toggles.
- Adds an extra space by default (`g:cmt_eol_insert_pad_space = true`) so typing after the leader stays aligned. Set it to `false` to skip padding.

### Fallbacks & logging

- If a filetype is listed in `g:cmt_disabled_filetypes`, cmt.nvim steps aside and lets stock `gc` handle everything.
- Errors (missing Tree-sitter, invalid `commentstring`, etc.) are logged via `vim.notify`. Adjust verbosity with `g:cmt_log_level`.
- `:CmtInfo` reports the current filetype, resolved mode, prefix/suffix, and source (Tree-sitter, fallback, buffer option, etc.).

---

## Configuration Reference

| Variable                     | Default                                                                                                               | Purpose                                                                                              |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `g:cmt_mixed_mode_policy`    | `{ typescriptreact = "first-line", javascriptreact = "first-line", default = "mixed" }`                               | Dict or string controlling mixed-region behaviour (`"mixed"`, `"first-line"`, `"line"`, `"block"`).  |
| `g:cmt_block_fallback`       | `{}`                                                                                                                  | Per-filetype fallback commentstrings, e.g. `{ tsx = { line = "// %s", block = { "{/*", "*/}" } } }`. |
| `g:cmt_disabled_filetypes`   | `{}`                                                                                                                  | Filetypes that should bypass cmt.nvim entirely.                                                      |
| `g:cmt_eol_insert_pad_space` | `true`                                                                                                                | Adds a trailing space when inserting `gco` / `gcO`.                                                  |
| `g:cmt_log_level`            | `"warn"`                                                                                                              | Logging threshold (`"error"`, `"warn"`, `"info"`, `"debug"`).                                        |
| `g:cmt_toggle_highlight`     | `{ enabled = true, duration = 200, groups = { comment = "CmtToggleCommented", uncomment = "CmtToggleUncommented" } }` | Controls the transient highlight applied to the most recent toggle.                                  |

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

vim.g.cmt_toggle_highlight = {
  enabled = true,
  duration = 200, -- milliseconds
  groups = {
    comment = "IncSearch",
    uncomment = "DiffDelete",
  },
}
```

---

### Toggle highlight flash

- `enabled` – turn the flash on/off globally (default: `true`).
- `duration` – how long (ms) to keep the highlight before it automatically clears (default: `200`).
- `groups.comment` / `groups.uncomment` – highlight groups used after adding or removing comments. Defaults link to `DiffAdd` / `DiffDelete`, so you can simply re-link `CmtToggleCommented` or `CmtToggleUncommented` in your colorscheme if you prefer.

For example:

```lua
vim.api.nvim_set_hl(0, "CmtToggleCommented", { bg = "#1d3b2f" })
vim.api.nvim_set_hl(0, "CmtToggleUncommented", { bg = "#3b1d1d" })
vim.g.cmt_toggle_highlight = { duration = 250 }
```

## Troubleshooting

- **Outputs plain `gc` behaviour**: ensure `nvim-ts-context-commentstring` is installed and attached, and the buffer isn’t listed in `g:cmt_disabled_filetypes`.
- **Always falls back to block comments**: Tree-sitter may only expose block modes for the selection. Adjust `g:cmt_mixed_mode_policy` (for example `"line"` or `"first-line"`).
- **`first-line` still block comments in JSX**: make sure you are invoking `gc` for line comments. `gw` is intentionally block-only unless overridden via the policy.
- **Need more detail**: run `:CmtInfo` to see the mode/prefix source or set `g:cmt_log_level = "info"` and check `:messages`.

---

## Development

```bash
# Install vusted via LuaRocks (make sure the installed bin dir is on your PATH)
luarocks --lua-version=5.1 install vusted

# Run the whole suite via vusted
VUSTED_ARGS="--headless --clean -u tests/vusted/init.lua" vusted lua/cmt/tests
```

If you install vusted into a custom tree (for example `luarocks --lua-version=5.1 --tree .rocks install vusted`), set `CMT_VUSTED_ROCKS=/absolute/path/to/.rocks` before running the tests so Neovim can discover the Lua modules.

Helper targets:

```bash
make format      # stylua lua tests
make test        # ensure local vusted tree + run suite
make ci          # stylua --check + tests
```

Layout overview:

1. `plugin/cmt.vim` – declares `<Plug>` mappings, operatorfunc hooks, defaults.
2. `lua/cmt/ops.lua` – routing layer (visual/operator dispatch, logging, fallbacks).
3. `lua/cmt/service.lua` – buffer edits, commentstring resolution, policy handling.
4. `lua/cmt/toggler.lua` – pure Lua transformations for line/block alignment.
5. `lua/cmt/commentstring.lua` – wrappers around `commentstring` sources and fallbacks.

PRs are welcome—keep code stylua-friendly and include tests (vusted) for behaviour changes.
