# Ansible

Installs this Neovim config's external toolchain from system packages, links the
config into `~/.config/nvim/`, installs the plugins headlessly, and verifies that
every tool the editor expects actually resolved on PATH.

## Run locally

```sh
ansible-galaxy collection install -r requirements.yml
just provision   # == cd ansible && ansible-playbook playbook.yml --ask-become-pass
```

## Where the tool list lives

`lua/toolchain/registry.lua` is the single source of truth: every LSP server,
formatter, linter and debug adapter, grouped by ecosystem the same way
`lua/scaffold/tools.lua` groups project tooling. From it are generated:

| artefact                              | contents                                                        |
| ------------------------------------- | --------------------------------------------------------------- |
| `roles/nvim/vars/tools.generated.yml` | `nvim_ecosystems` — packages, bootstrap steps, bin paths, tools |
| `AUR-dependencies.txt`                | the human-readable package overview                             |

Regenerate both with `just toolchain-export`; `just toolchain-check` (also a
pre-commit hook) fails if they drifted from the registry. Adding a language is one
row in the registry — the role, the docs and the editor all follow.

## What the role does

1. **Removes packages the toolchain replaces** (`nvim_conflicting_packages`),
   since pacman refuses a transaction that conflicts with what is installed — the
   repo `zls` against the AUR `zls-bin` that matches the installed compiler, and
   `vscode-json-languageserver` against `vscode-langservers-extracted`, which own
   the same `/usr/bin/vscode-json-language-server`.
2. **Installs every package** in one yay transaction (repo and AUR alike).
3. **Runs the bootstrap steps** no package can cover: rustup components, luarocks
   rocks, `cargo install bacon-ls`, and the unpackaged lua debug adapter. Each step
   is idempotent and guarded by `creates`.
4. **Links the config**, refusing to clobber a checkout with uncommitted changes.
5. **Syncs the plugins** with `nvim --headless "+Lazy! sync" +qa`.
6. **Builds the treesitter parsers** with `nvim --headless "+TSSyncInstall" +qa`;
   the editor's own install is async and would lose the race with `+qa`.
7. **Refreshes the tool store** and fails if a required tool is missing.

## The tool store

Neovim owns `~/.local/state/nvim/tools.json` and rewrites it on idle after startup,
on `:ToolchainRefresh`, and at the end of a provision run. Ansible only reads it.
It is the interface for status bars and dashboards:

```json
{
  "schema": 1,
  "generated_at": "2026-08-28T00:00:00Z",
  "summary": { "total": 60, "present": 58, "missing": 2, "missing_tools": [] },
  "ecosystems": {
    "rust": {
      "packages": ["rustup", "rust-analyzer", "bacon", "codelldb-bin"],
      "present": 6,
      "missing": 0,
      "tools": [
        {
          "name": "rust_analyzer",
          "kind": "lsp",
          "ecosystem": "rust",
          "binary": "rust-analyzer",
          "package": "rust-analyzer",
          "present": true,
          "path": "/usr/bin/rust-analyzer",
          "version": "rust-analyzer 0.3.3025-standalone",
          "mtime": 1787841674,
          "optional": false
        }
      ]
    }
  }
}
```

Writes are atomic (tmp + rename), so a reader never sees half a document. `kind` is
one of `lsp`, `fmt`, `lint`, `dap`, `tool`.

## Failure notifications

Every failing step raises a desktop notification through
`~/.local/bin/nvim-tool-notify` and appends one JSON object to
`~/.local/state/nvim/toolchain-events.jsonl`. The notification carries the same
fields as hints, so a client reads them instead of scraping the text:

| hint               | example                                      |
| ------------------ | -------------------------------------------- |
| `x-nvim-phase`     | `packages`, `bootstrap`, `plugins`, `verify` |
| `x-nvim-ecosystem` | `rust`                                       |
| `x-nvim-tool`      | `cargo-bacon-ls`                             |
| `x-nvim-exit`      | `101`                                        |
| `x-nvim-timestamp` | `2026-08-28T00:00:00+02:00`                  |
| `x-nvim-log`       | path of the failure log                      |
| `x-nvim-store`     | path of the tool store                       |

App name is `nvim-toolchain`, category `nvim.toolchain.failed`. `:ToolchainUpdate`
writes to the same log with `"source": "nvim"`, so one file carries everything that
happened to the toolchain.

## Editor commands

| command                  | effect                                                       |
| ------------------------ | ------------------------------------------------------------ |
| `:ToolchainStatus`       | report present/missing counts from the store                 |
| `:ToolchainRefresh`      | re-probe PATH and rewrite the store                          |
| `:ToolchainExport`       | regenerate the role's vars and the package overview          |
| `:checkhealth toolchain` | missing tools, plus any binary resolving outside its package |

## Import from a controller

```yaml
- hosts: workstation
  roles:
    - role: nvim
      vars:
        nvim_repo_path: /path/to/checkout
        nvim_ecosystem_filter: [core, lua, rust] # default: every ecosystem
```

## Shared state

The tool store writes to the desk's shared quantum-store directory
(`$QF_STORE/nvim/tools.json`; `$QF_STORE` defaults to
`$XDG_STATE_HOME/quantum-store`, exported by the desktop's session env). The
role resolves the same point (`nvim_qf_store_dir`) around the refresh, and
`lib/toolchain` adopts a legacy copy on read.
