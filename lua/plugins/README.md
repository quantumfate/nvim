# plugins

lazy.nvim specs only. Logic goes in `lua/features/`.

| Directory      | Holds                                               |
| -------------- | --------------------------------------------------- |
| `coding/`      | LSP-adjacent: completion, format, lint, test, debug |
| `editor/`      | motions, search, git, folds, trees                  |
| `lang/`        | per-language specs and `lspconfig`                  |
| `lib/`         | snacks, mini, snippets                              |
| `ui/`          | colorscheme, statusline, panels                     |
| `misc/` `dev/` | everything else                                     |

## Rules

- Every spec needs `event`, `keys`, `cmd` or `ft`. Two exceptions load at startup:
  `snacks.nvim` and `catppuccin`.
- No `require()` at spec-eval scope — it drags the plugin into startup. Put it inside
  `opts = function()`, `config`, or a `keys` callback.
- Formatters and linters are not listed here. They come from
  [`lua/toolchain/registry.lua`](../toolchain/README.md) via `by_ft`.

Check what actually loaded at startup:

```vim
:lua =vim.tbl_count(vim.tbl_filter(function(p) return p._.loaded end, require("lazy.core.config").plugins))
```
