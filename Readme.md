# My neovim config

![nvim](./assets/nvim-dashboard.png)

## Minimum effort lazy loading

![lazy](./assets/lazy.png)

## Debugging

![debug](./assets/depug.png)

## Dependencies

### Core (required)

| Dep | Why |
| --- | --- |
| `neovim` > v0.11 | editor (nightly recommended) |
| `git` | plugin manager (lazy.nvim) + lazygit |
| C compiler (`gcc`/`clang`) + `make` | builds treesitter parsers |
| `tree-sitter-cli` | parser install on the `main` branch |
| `ripgrep` | grep/picker backend |
| `fd` | file finder backend |
| `fzf` | fuzzy matching |

### Language runtimes

Needed so the Mason-installed tools (below) actually run.

| Runtime | Feeds |
| --- | --- |
| `nodejs` + `npm` (or `pnpm`) | ts_ls, tailwindcss, prettierd, eslint_d, js-debug-adapter |
| `go` | gopls, goimports, gofmt, delve |
| `rustup` / `cargo` | rust-analyzer, rustfmt, codelldb |
| `python` + `pip`/`uv` | basedpyright, black, ruff, debugpy |
| `lua51` + `luarocks` | lua_ls, stylua |

### Auto-installed via Mason

These install on first launch (`:Mason`), no manual action needed — but they
depend on the runtimes above.

- **LSP**: lua_ls, basedpyright, ts_ls, rust_analyzer, gopls, clangd, jsonls,
  yamlls, ansiblels, tailwindcss, bashls, qmlls, svelte-language-server, taplo,
  marksman
- **Formatters**: stylua, prettierd, black, ruff, shfmt, clang-format,
  goimports, rustfmt, deno
- **Linters**: eslint_d, shellcheck, markdownlint, yamllint, hadolint,
  ansible_lint, jsonlint, cpplint
- **DAP**: debugpy, codelldb, js-debug-adapter, delve

### Optional

- `lazygit` — git UI (`<leader>gg`)
- `devpod` — dev containers

## Remarks

- very inspired by [LazyVim](https://www.lazyvim.org/)
- thank you tony btw for ts queries [TonyBtw/nvim](https://github.com/tonybanters/nvim.git)

