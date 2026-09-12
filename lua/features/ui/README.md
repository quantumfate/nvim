# UI & UX Library

Centralized UI subsystem providing mutually exclusive edge slots, modal keymap profiles,
and full-editor layout snapshots.

## Modules

| File          | Holds                                                                       |
| ------------- | --------------------------------------------------------------------------- |
| `init.lua`    | `ui.setup()`, `ui.focus_left()` smart edge navigation                       |
| `slot.lua`    | `ui.slot`: mutually exclusive slot engine with history and toggle           |
| `sidebar.lua` | `ui.sidebar`: Files / Buffers / Git taking turns in one left-edge window    |
| `mode.lua`    | `ui.mode`: scoped modal keymaps (debug, review) with guaranteed restoration |
| `layout.lua`  | `ui.layout`: window topology and viewport snapshots across workflow presets |

## Mutually Exclusive Sidebar

One explorer window, ever, on the left edge. Three views take turns in it: **Files**
(`filesystem`), **Buffers** (`buffers`) and **Git** (`git_status`). Switching replaces
the view in place instead of opening a second tree, so there are no collapsed 1-line
slices for `wincmd h` to land in.

| Key          | Does                                     |
| ------------ | ---------------------------------------- |
| `<leader>ee` | Files — press again to close the sidebar |
| `<leader>eb` | Buffers — press again to close           |
| `<leader>eg` | Git status — press again to close        |
| `<leader>ge` | Git status, from the git group           |
| `<leader>eE` | Files, rooted at the current file's dir  |
| `<leader>wh` | Jump into the sidebar from the left edge |

Every binding toggles: the key that opened a view closes it, and a different key
swaps the view without leaving the sidebar. There are no navigation keys inside the
pane — `<Tab>` and `1`/`2`/`3` belong to neo-tree, not to us.

`<leader>wh` runs `ui.focus_left()`: a normal `wincmd h`, except that hitting the left
edge focuses the active sidebar instead of doing nothing. In tmux this depends on
tmux not swallowing the prefix first; `:lua require("features.ui").focus_left()` is
the same action without the keymap.

### API

```lua
local sidebar = require("features.ui.sidebar")
sidebar.toggle("git_status")  -- open, or close if already showing
sidebar.switch("buffers")     -- always open, replacing whatever is there
sidebar.active_source()       -- "filesystem" | "buffers" | "git_status" | nil
sidebar.is_open()
sidebar.focus()
```

## Modal Keymap Profiles

Temporarily overrides standard bindings with scoped one-offs during specific workflows,
automatically restoring original keymaps on teardown:

- **Debug Mode (`ui.mode.enter("debug")`)**:
  - Activated automatically on DAP launch/attach or via `<leader>dD`.
  - Single-key bindings: `c` continue, `n` step over, `s` step into, `o` step out, `b` breakpoint, `q` exit.
  - Snapshots normal code layout and restores it upon exit.

## Layout Snapshots

`ui.layout.snapshot(name)` and `ui.layout.restore(name)` capture window topology, buffers,
and viewports so complex operations can morph the editor and cleanly restore previous state.
