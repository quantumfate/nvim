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
  `<leader>v` inspects in Rust, C, Zig, Go, Python and Lua alike — see
  [`lua/features/lang/`](./lua/features/lang/README.md).
- The binary is a source of truth too: `<leader>x` shows struct holes, the linked
  machine code, sanitizer frames and the kernel-tree workflow — see
  [`lua/features/sys/`](./lua/features/sys/README.md).
- Crashes open like files: `<leader>dc` picks a core dump and `<CR>` jumps to the
  faulting line — see [`lua/features/crash/`](./lua/features/crash/README.md).
- Windows have names, and transient views borrow a pane instead of opening their own —
  see [`lua/features/workspace/`](./lua/features/workspace/README.md).

## Why

Linux lost the mainstream to config files and CLI tools. Agents love exactly that, so
everyone building with agents now depends on Linux and its stability. This config is the
training ground for the layer underneath: it shows what the machine does with code —
assembly, layouts, crashes, syscalls, the kernel — through tools an agent can drive too.

## Roadmap

Tracked in the Linear project
[Neovim Configuration](https://linear.app/quantumfate/project/neovim-configuration-382d73d48a3b).
Issues carry a `Module` label named after a directory below; each module README names its
label.

| Milestone                  | Done when                                                             |
| -------------------------- | --------------------------------------------------------------------- |
| M1 · Trustworthy core      | tests isolated and green in CI, no crash on save, verify never lies  |
| M2 · Read the machine      | layout, binary, profile, syscalls, crashes — every language, to source |
| M3 · Change code safely    | every declaration, impl and override updated, or a conflict           |
| M4 · Kernel workflow       | a real tree: navigate, check, boot in QEMU, debug, decode, send       |
| M5 · Headless & scriptable | every analysis as a headless command with JSON output                 |
| M6 · Practice & proof      | playground sessions by hand, a kernel study, write-ups                |
| Neovim Agent Management    | the agent dashboard                                                   |

## Screens

| Lazy loading               | Debugging                    |
| -------------------------- | ---------------------------- |
| ![lazy](./assets/lazy.png) | ![debug](./assets/depug.png) |

## Remarks

- very inspired by [LazyVim](https://www.lazyvim.org/)
- thank you tony btw for ts queries [TonyBtw/nvim](https://github.com/tonybanters/nvim.git)
