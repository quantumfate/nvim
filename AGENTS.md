# Agent notes

This repo is my Neovim 0.11+ config: lazy.nvim, no Mason — every external tool
is a system package provisioned by the sibling
[system-config](https://github.com/quantumfate/system-config) (deployed from
this repo's own `ansible/` role).

## Read order

New to the repo, read in this order — each layer points at the next:

1. [Readme.md](Readme.md) — the dependency-arrow diagram and the two rules.
2. The per-directory `README.md` (`lua/core/`, `lua/lib/`, `lua/features/`,
   `lua/plugins/`, `lua/theme/`, `lua/toolchain/`, `lua/scaffold/`) — a layer
   may only require where its arrows point.
3. `lua/toolchain/README.md` when touching formatters/linters/LSP — everything
   is declared once in [`lua/toolchain/registry.lua`](lua/toolchain/README.md).
4. `tests/README.md` — the regression specs (`just test`).

## Repo map

| Path             | Owns                                                       |
| ---------------- | ---------------------------------------------------------- |
| `lua/core/`      | options, filetypes, autocmds, keymaps                      |
| `lua/lib/`       | generic, knows no plugin (root detection, lazy-require, …) |
| `lua/features/`  | the code plugin specs call into                            |
| `lua/plugins/`   | lazy specs + lazy-loading rules only                       |
| `lua/theme/`     | colorscheme switching, `:Theme`                            |
| `lua/toolchain/` | tool inventory + `:Toolchain*`, the JSON store             |
| `lua/scaffold/`  | `:ProjectScaffold`, `:ProjectDoctor`                       |
| `ansible/`       | provisioning the tools (from a role inside this checkout)  |
| `tests/`         | regression tests driving a real editor, one nvim per spec  |

## Contract

- A plugin's **spec** lives in `lua/plugins/`, its **code** in
  `lua/features/`. No logic in specs, no plugin knowledge in `lib/`.
- Formatters, linters, LSP servers are declared **once** in
  `lua/toolchain/registry.lua`; conform and nvim-lint derive their filetype
  maps from it. Never list them a second time.
- Tool installation is a system-package concern: add the tool to this repo's
  Ansible role (or system-config), never to a Mason-like installer.
- Refactorings build a plan and apply none of it (preview, conflict gating,
  cross-file undo are shared) — see `lua/features/refactor/README.md`.

## Commands

```sh
just check          # fmt-check + the full static gate
just test           # regression tests (nvim --headless tests/run.lua)
just test-one SPEC  # one spec, headless
just fmt            # stylua + prettier in place
```

## Style

- `stylua` + `luacheck` clean; match neighboring Lua's comment voice.
- Keymaps and actions are keyed by question, not language: `<leader>b` builds,
  `<leader>t` tests, `<leader>d` debugs, `<leader>v` inspects — language
  parity comes from the features layers, not per-language bindings.
