# My neovim config

![nvim](./assets/nvim-dashboard.png)

## Minimum effort lazy loading

![lazy](./assets/lazy.png)

## Debugging

![debug](./assets/depug.png)

## Navigation

### Layout

Adapted for my [Programmer Dvorak Layout](https://codeberg.org/quantumfate/system-config/src/branch/main/roles/keyboard).

```text
-  =  ]   forward / next          _  =  [   backward / previous
```

**Counts are expensive.** Digits are the shifted level of the number row, so
`7j` is a chord. Reach for structure instead, in this order:

1. a structural motion — `-f`, `_c`, `g_f`
2. flash — `s` plus two characters
3. a textobject with `n` / `l` — `cin(` needs no count at all
4. a count, only for 2 or 3

### Pick the scale

| Distance                    | Tool                 | Keys                      |
| --------------------------- | -------------------- | ------------------------- |
| Within the line             | `f` / `t` + `;`      | `dt(`                     |
| Visible on screen           | flash                | `s` + 2 chars + label     |
| Within the function         | search, `%`, `{` `}` | `/name` `*`               |
| Within the file, structural | bracket motions      | `-f` `_c` then `;`        |
| Within the file, by name    | pickers              | `<leader>fs` `<leader>cn` |
| Another file                | LSP, harpoon, marks  | `gd` `<C-h>` `` `A ``     |

### Textobjects — mini.ai

```text
operator  +  count  +  a | i | an | in | al | il  +  object
```

`a` around, `i` inside, `n` next, `l` last. `g_` / `g-` jump to an object's start
/ end without an operator.

| Key     | Object                     | Key     | Object                      |
| ------- | -------------------------- | ------- | --------------------------- |
| `f`     | function                   | `a`     | argument                    |
| `c`     | class                      | `t`     | tag                         |
| `o`     | block / conditional / loop | `i`     | indent block                |
| `u` `U` | function call              | `d`     | digits                      |
| `v`     | assignment (`iv` = value)  | `e`     | CamelCase / snake_case part |
| `r`     | return statement           | `g`     | entire buffer               |
| `C`     | comment                    | `q` `b` | any quote / any bracket     |

```text
dif     delete the function body        cin(   change inside the NEXT parens
vaf     select the whole function       dala   delete the LAST argument
civ     replace an assignment's value   g_f    start of enclosing function
dar     delete a return statement       d g-f  delete to end of function
```

`cin(` and `dala` are the payoff: they operate on things the cursor is not in.

### Structural motions — treesitter

Lowercase lands on the node start, uppercase on the node end.

| Key       | Node      | Key       | Node        |
| --------- | --------- | --------- | ----------- |
| `-f` `_f` | function  | `-i` `_i` | conditional |
| `-c` `_c` | class     | `-l` `_l` | loop        |
| `-a` `_a` | parameter | `-v` `_v` | assignment  |
| `-o` `_o` | block     | `-r` `_r` | return      |

**`;` repeats the last motion, `,` reverses it.** `-f;;;` walks the file by
function — press the prefix once, then walk. `;` still repeats `f` / `t` when
that was the last move.

`-f` leaves the current function; `g_f` stays inside it and goes to its start;
`vaf` does not move at all and selects it.

### Selection

```text
<C-space>   grow the selection to the enclosing node
<BS>        shrink back one step
S           flash treesitter — label every node, jump to one
```

### Moving code

Four directions on the right hand's home row, which occupies the physical slots
QWERTY gives `hjkl`:

```text
<A-d>  parameter left     <A-n>  parameter right
<A-h>  line / selection down     <A-t>  line / selection up
```

```text
<leader>ma / mA   swap parameter forward / backward
<leader>mf / mF   swap function
<leader>mc / mC   swap class
<leader>mv / mV   swap assignment
<leader>md / mD   duplicate the enclosing function / class
```

Relocating rather than reordering: `daf` → `-f` → `p`. Surround lives on `gs`
so `s` stays free for flash: `gsaif)` wraps a function body in parens.

### Jumping

```text
s   jump anywhere on screen: 2 chars, then a label
S   label treesitter nodes
r   remote — operate on a distant object without leaving home (operator-pending)
R   treesitter search

/ ? * #     search; `/` is an operator motion: d/return<CR>
% { } H M L zz zt zb

ma `a       buffer-local mark            mA `A   global mark, survives files
`` `.       last position / last edit    g; g,   walk the changelist
<C-o> <C-i> jumplist back / forward
```

`gn` selects the next search match as a textobject, which is the multi-cursor
this config ships with:

```text
/oldName<CR>   cgn newName<Esc>   then  . . .
```

### Symbols, LSP, files

```text
gd gD gy gI gO        definition, declaration, type, implementation, symbols
grr grn gra gri grt   references, rename, code action, implementation, type
K                     hover
<leader>cn            navbuddy symbol tree
<leader>fs            treesitter symbol picker
<leader>fll           LSP document symbols

<leader>ha            harpoon add
<C-h> <C-t> <C-n>     harpoon slots 1-3
<leader>hl            harpoon picker
<C-f>                 tmux sessionizer
```

### Where the bindings live

| Layer                  | Owns                                | File                                |
| ---------------------- | ----------------------------------- | ----------------------------------- |
| flash                  | `s` `S` `r` `R`                     | `lua/plugins/editor/flash.lua`      |
| treesitter-textobjects | motions, `<leader>m` swaps, `;` `,` | `lua/plugins/editor/treesitter.lua` |
| mini.ai                | `a` `i` `n` `l` `g-` `g_`           | `lua/plugins/lib/mini-ai.lua`       |
| mini.surround          | `gs*`                               | `lua/plugins/lib/mini-surround.lua` |
| LSP                    | `g*` navigation                     | `lua/plugins/lang/conf/keymaps.lua` |
| config                 | prefixes, windows, lists, drags     | `lua/config/keymaps.lua`            |

If a mapping does not behave as documented, `:verbose map <lhs>` names the file
that won — anything loading on an event overrides `lua/config/keymaps.lua`.

## Toolchain

Every external tool — LSP servers, formatters, linters, debug adapters — is a system
package, installed by the ansible role. There is no Mason.

### How it fits together

```text
lua/toolchain/registry.lua
        │
        ├─ generates ─→ ansible/roles/nvim/vars/tools.generated.yml ─→ the role installs
        ├─ generates ─→ AUR-dependencies.txt
        └─ describes ─→ ~/.local/state/nvim/tools.json ─→ read by quickshell, the dashboard
```

Four rules hold the whole thing together:

1. **One owner per binary.** A tool comes from pacman, or from a bootstrap step, never
   both. Two installs of one binary drift apart and the wrong one wins PATH.
2. **The registry is the source of truth for the entire system.** Both generated files are built from it and committed.
   Never edit them by hand; `just toolchain-export` rewrites them, `just toolchain-check`
   fails the commit if they drifted.
3. **Neovim owns the store, ansible only reads it.** The role installs; the editor
   reports what actually resolved. Nothing else writes that file.
4. **Updates are manual.** A dashboard is supplied to manage updates outside of the system's package manager.

### Using it

```sh
just provision        # install everything and link the config
just toolchain-status # what resolved on PATH right now
```

`<leader>it` opens the dashboard: every ecosystem with a present/total bar, each
tool's version and path, the last events, and the update actions (`u` everything,
`U` the ecosystem under the cursor, `r` re-probe, `e` the event log).

### Updating

| Layer               | How                                     |
| ------------------- | --------------------------------------- |
| Packages            | `yay -Syu` — outside this repo entirely |
| tool local upgrades | `:ToolchainUpdate`                      |
| Plugins             | `:ToolchainUpdate` (or `:Lazy update`)  |

`:ToolchainUpdate` runs one step at a time, alerts through `notify-send` per step and
once at the end, writes every outcome to the event log, then refreshes the store.

### Manifest

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

Details, including the full role behaviour: [`ansible/Readme.md`](./ansible/Readme.md).

## Remarks

- very inspired by [LazyVim](https://www.lazyvim.org/)
- thank you tony btw for ts queries [TonyBtw/nvim](https://github.com/tonybanters/nvim.git)
