# UI & UX Library

Centralized UI subsystem providing mutually exclusive edge slots, modal keymap profiles,
and full-editor layout snapshots.

## Modules

| File          | Holds                                                                       |
| ------------- | --------------------------------------------------------------------------- |
| `init.lua`    | `ui.setup()`, `ui.focus_left()` smart edge navigation                       |
| `slot.lua`    | `ui.slot`: mutually exclusive slot engine with history and toggle           |
| `sidebar.lua` | `ui.sidebar`: vertical view array (Files, Buffers, Git), single window slot |
| `mode.lua`    | `ui.mode`: scoped modal keymaps (debug, review) with guaranteed restoration |
| `layout.lua`  | `ui.layout`: window topology and viewport snapshots across workflow presets |

## Mutually Exclusive Sidebar

Only ONE explorer window occupies the left edge, eliminating collapsed 1-line window slices
that trap horizontal spatial cursor navigation (`<leader>wh` / `wincmd h`):

- **Active View at Top**: The active source (Files, Buffers, or Git) fills the sidebar height.
- **In-Window Switching**: Sources replace each other inside the same window rather than stacking.
- **Keymaps inside Sidebar**:
  - `<Tab>` / `<S-Tab>`: cycle through views
  - `1`: switch to Files (`filesystem`)
  - `2`: switch to Buffers (`buffers`)
  - `3`: switch to Git (`git_status`)
- **Global Keymaps**:
  - `<leader>ee`: toggle/focus Files
  - `<leader>eb`: switch to Buffers
  - `<leader>ge`: switch to Git Status
  - `<leader>wh`: navigates left directly into the active sidebar window.

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
