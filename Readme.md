# My neovim config

![nvim](./assets/nvim-dashboard.png)

## Minimum effort lazy loading

![lazy](./assets/lazy.png)

## Debugging

![debug](./assets/depug.png)

## Toolchain

Every external tool — LSP servers, formatters, linters, debug adapters — is a
system package installed by the ansible role. There is no Mason: one copy of each
binary, one thing that updates it (`yay -Syu`).

```sh
just provision        # install everything and link the config
just toolchain-status # what resolved on PATH right now
```

### Manifest

| Artefact                                       | Owner     | What it is                                                                                                 |
| ---------------------------------------------- | --------- | ---------------------------------------------------------------------------------------------------------- |
| `lua/toolchain/registry.lua`                   | you       | **Source of truth.** Every tool, grouped by ecosystem, with its package name. Adding a language is one row |
| `ansible/roles/nvim/vars/tools.generated.yml`  | generated | The role's package list, bootstrap steps and bin paths                                                     |
| `AUR-dependencies.txt`                         | generated | Human-readable package overview                                                                            |
| `~/.local/state/nvim/tools.json`               | neovim    | **The store.** What is present, its path, its version, what is missing                                     |
| `~/.local/state/nvim/toolchain-failures.jsonl` | ansible   | One JSON line per failed provisioning step                                                                 |

Both generated files are committed. Regenerate with `just toolchain-export`;
`just toolchain-check` (a pre-commit hook, and part of `just check`) fails if they
drifted from the registry. The role reads them — it never writes them.

### Commands

| Command                  | Effect                                                       |
| ------------------------ | ------------------------------------------------------------ |
| `:ToolchainStatus`       | present/missing counts from the store                        |
| `:ToolchainRefresh`      | re-probe PATH and rewrite the store                          |
| `:ToolchainExport`       | regenerate the vars file and the package overview            |
| `:checkhealth toolchain` | missing tools, plus any binary resolving outside its package |

### Using the store

The store is the interface for anything outside the editor — a status bar, a
dashboard, an update hook. Neovim rewrites it 2s after startup, on
`:ToolchainRefresh`, and at the end of a provision run; writes are atomic, so a
reader never sees half a document.

```sh
jq '.summary' ~/.local/state/nvim/tools.json
# { "total": 60, "present": 60, "missing": 0, "missing_tools": [] }

jq -r '.ecosystems.rust.tools[] | "\(.name) \(.version // "?")"' ~/.local/state/nvim/tools.json
```

Each tool carries `name`, `kind` (`lsp`/`fmt`/`lint`/`dap`/`tool`), `ecosystem`,
`binary`, `package`, `present`, `path`, `version`, `mtime`, `optional`. Versions
are cached by binary mtime, so a `yay -Syu` that upgrades a tool shows its new
version after the next neovim start or `:ToolchainRefresh`.

Failures during provisioning also raise a desktop notification (app name
`nvim-toolchain`, category `nvim.toolchain.failure`) whose hints carry the same
fields — `x-nvim-phase`, `x-nvim-ecosystem`, `x-nvim-tool`, `x-nvim-exit`,
`x-nvim-timestamp`, `x-nvim-log`, `x-nvim-store` — so a client reads those instead
of parsing the message text.

Details, including the full role behaviour: [`ansible/Readme.md`](./ansible/Readme.md).

## Remarks

- very inspired by [LazyVim](https://www.lazyvim.org/)
- thank you tony btw for ts queries [TonyBtw/nvim](https://github.com/tonybanters/nvim.git)
