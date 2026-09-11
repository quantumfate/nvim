# Toolchain

Every external tool — LSP servers, formatters, linters, debug adapters — is a system
package, installed by the ansible role. There is no Mason.

## How it fits together

```text
lua/toolchain/registry.lua
        │
        ├─ generates ─→ ansible/roles/nvim/vars/tools.generated.yml ─→ the role installs
        ├─ generates ─→ AUR-dependencies.txt
        ├─ describes ─→ ~/.local/state/nvim/tools.json ─→ read by quickshell, the dashboard
        └─ by_ft() ──→ conform formatters_by_ft
                   └─→ nvim-lint linters_by_ft
```

A tool is wired to a language by its `ft` field here, never in a plugin spec:

```lua
{ name = "stylua", bin = "stylua", ft = { "lua" } }
{ name = "prettierd", alt = true, bin = "prettierd", ft = PRETTIER_FT }
```

`alt` marks alternatives rather than pipeline stages — `{ prettierd, prettier }` is one
formatter with a fallback, `{ ruff_organize_imports, ruff_format }` is two that both
run. conform gets `stop_after_first`; nvim-lint takes only the first.

`:checkhealth toolchain` reports drift between the registry and
`lua/features/lsp/servers.lua`.

Four rules hold the whole thing together:

1. **One owner per binary.** A tool comes from pacman, or from a bootstrap step, never
   both. Two installs of one binary drift apart and the wrong one wins PATH.
2. **The registry is the source of truth for the entire system.** Both generated files are built from it and committed.
   Never edit them by hand; `just toolchain-export` rewrites them, `just toolchain-check`
   fails the commit if they drifted.
3. **Neovim owns the store, ansible only reads it.** The role installs; the editor
   reports what actually resolved. Nothing else writes that file.
4. **Updates are manual.** A dashboard is supplied to manage updates outside of the system's package manager.

## Using it

```sh
just provision        # install everything and link the config
just toolchain-status # what resolved on PATH right now
```

`<leader>it` opens the dashboard: every ecosystem with a present/total bar, each
tool's version and path, the last events, and the update actions (`u` everything,
`U` the ecosystem under the cursor, `r` re-probe, `e` the event log).

## Updating

| Layer               | How                                     |
| ------------------- | --------------------------------------- |
| Packages            | `yay -Syu` — outside this repo entirely |
| tool local upgrades | `:ToolchainUpdate`                      |
| Plugins             | `:ToolchainUpdate` (or `:Lazy update`)  |

`:ToolchainUpdate` runs one step at a time, alerts through `notify-send` per step and
once at the end, writes every outcome to the event log, then refreshes the store.

## Manifest

| Artefact                                       | What it is                                                                                                 |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `lua/toolchain/registry.lua`                   | **Source of truth.** Every tool, grouped by ecosystem, with its package name. Adding a language is one row |
| `ansible/roles/nvim/vars/tools.generated.yml`  | The role's package list, bootstrap steps and bin paths                                                     |
| `AUR-dependencies.txt`                         | Human-readable package overview                                                                            |
| `~/.local/state/nvim/tools.json`               | **The store.**                                                                                             |
| `~/.local/state/nvim/toolchain-failures.jsonl` | One JSON line per failed provisioning step                                                                 |

Both generated files are committed. Regenerate with `just toolchain-export`;
`just toolchain-check` (a pre-commit hook, and part of `just check`) fails if they
drifted from the registry. The role reads them — it never writes them.

## Commands

| Command                  | Effect                                                       |
| ------------------------ | ------------------------------------------------------------ |
| `:ToolchainStatus`       | present/missing counts from the store                        |
| `:ToolchainRefresh`      | re-probe PATH and rewrite the store                          |
| `:ToolchainExport`       | regenerate the vars file and the package overview            |
| `:checkhealth toolchain` | missing tools, plus any binary resolving outside its package |

## Using the store

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
`binary`, `package`, `present`, `path`, `version`, `version_source`, `probe`,
`mtime`, `optional`. `version_source` is `probe` when the tool reported its own
version and `package` when it could not and pacman answered instead.

Troubleshooting a version that looks wrong: `probe` records the exact command that
produced it, so re-run it in a scratch directory (`cd $(mktemp -d)`, never the
repo), and `pacman -Qo <path>` says which package owns the binary. Set
`version_args` in the registry to fix it, or `false` when the tool has no version
flag at all.

Versions are cached by binary mtime, so a `yay -Syu` that upgrades a tool shows its new
version after the next neovim start or `:ToolchainRefresh`.

Updates and provisioning both raise desktop notifications (app name
`nvim-toolchain`, category `nvim.toolchain.ok` / `.failed`) whose hints carry the
same fields as the event log — `x-nvim-phase`, `x-nvim-ecosystem`, `x-nvim-tool`, `x-nvim-exit`,
`x-nvim-timestamp`, `x-nvim-status`, `x-nvim-log`, `x-nvim-store` — so a client
reads those instead of parsing the message text.

Details, including the full role behaviour: [`ansible/Readme.md`](../../ansible/Readme.md).
