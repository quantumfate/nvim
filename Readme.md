# My neovim config

![nvim](./assets/nvim-dashboard.png)

Neovim 0.11+, lazy.nvim, no Mason — every external tool is a system package.

## Architecture

Arrows point at what a layer is allowed to require.

```text
  init.lua
     ├── core/ ─────────────────┐
     └── lazy.nvim              │
           └── plugins/ ────────┤     specs; no logic
                 ├── features/ ─┤     the code specs call into
                 ├── theme/ ────┤     roles → highlights, on a ColorScheme hook
                 └── toolchain/ ┤     one tool inventory, read by conform + nvim-lint
                       scaffold/┘
                                └──> lib/    generic, knows no plugin
```

| Directory                                     | Holds                                      |
| --------------------------------------------- | ------------------------------------------ |
| [`lua/core/`](./lua/core/README.md)           | options, filetypes, autocmds, **keymaps**  |
| [`lua/lib/`](./lua/lib/README.md)             | root detection, lazy-require, cursor state |
| [`lua/features/`](./lua/features/README.md)   | refactoring engine, lsp, lualine, edgy     |
| [`lua/plugins/`](./lua/plugins/README.md)     | lazy specs, and the lazy-loading rules     |
| [`lua/theme/`](./lua/theme/README.md)         | colorscheme switching, `:Theme`            |
| [`lua/toolchain/`](./lua/toolchain/README.md) | `:Toolchain*`, the JSON store              |
| [`lua/scaffold/`](./lua/scaffold/README.md)   | `:ProjectScaffold`, `:ProjectDoctor`       |
| [`ansible/`](./ansible/Readme.md)             | provisioning the tools                     |
| [`tests/`](./tests/README.md)                 | regression tests — `just test`             |

## Two rules

- A plugin's **spec** lives in `lua/plugins/`, its **code** in `lua/features/`.
- Formatters, linters and LSP servers are declared once, in
  [`lua/toolchain/registry.lua`](./lua/toolchain/README.md). conform and nvim-lint
  derive their filetype maps from it.
- Refactorings build a plan and apply none of it, so preview, conflict gating and
  cross-file undo are shared — see
  [`lua/features/refactor/`](./lua/features/refactor/README.md).
- Language actions are keyed by question, not by language: `<leader>b` builds and
  runs, `<leader>t` tests, `<leader>d` debugs and `<leader>v` inspects in Rust, C,
  Zig, Go, Python and Lua alike — see
  [`lua/features/lang/`](./lua/features/lang/README.md).
- The binary is a source of truth too: `<leader>x` shows struct holes, the linked
  machine code, sanitizer frames, rr record/replay, and the kernel-tree workflow (b4,
  checkpatch, Kconfig, QEMU) — see [`lua/features/sys/`](./lua/features/sys/README.md).
- Crashes open like files: `<leader>dc` picks a core dump, `:CrashDecode` resolves
  vmlinux and module `.ko` frames, and `<CR>` jumps to the faulting line — see
  [`lua/features/crash/`](./lua/features/crash/README.md).
- Windows have names, and transient views borrow a pane instead of opening their own —
  see [`lua/features/workspace/`](./lua/features/workspace/README.md).

## Screens

| Lazy loading               | Debugging                    |
| -------------------------- | ---------------------------- |
| ![lazy](./assets/lazy.png) | ![debug](./assets/depug.png) |

## Remarks

- very inspired by [LazyVim](https://www.lazyvim.org/)
- thank you tony btw for ts queries [TonyBtw/nvim](https://github.com/tonybanters/nvim.git)
