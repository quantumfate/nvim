# Workspace

Named window slots, so things appear where you expect them.

```text
┌──────┬───────────────┬───────────────┬─────────┐
│ tree │     main      │      aux      │ outline │
└──────┴───────────────┴───────────────┴─────────┘
├──────────────────  dock  ───────────────────────┤
```

`main` and `aux` are ordinary editor windows. The rest are edges that toggle.

Every key that opens something closes it again with the same key — there and back,
rather than one-way and then hunting for how to undo it. That holds for `<leader>wz`,
the dock, the outline, and every `<leader>v` view.

**Exactly two content panes.** A third is width taken from the two you were reading, so
anything beyond the first two is closed — `enforce_two` runs before every layout and
every borrow, and again whenever a file lands in a window. Closing a window does not
touch its buffer: the file stays loaded and one `:b` away.

Content means editors _and_ renderings. Counting only editors meant
`main.c | main.c | c asm` read as two panes and nothing was closed. The safety net on
`BufWinEnter` exists because plugins split on their own terms — neo-tree splits rather
than reuse a pane that is pinned — and chasing each one would be a losing game.

|                                 |                            |
| ------------------------------- | -------------------------- |
| `<leader>wz`                    | build the canonical layout |
| `<leader>wo`                    | toggle the outline         |
| `<leader>wa`                    | focus the aux pane         |
| `<leader>wi` / `:WorkspaceInfo` | which window is which slot |

## Borrowing

The reason it feels predictable: a transient view does not create a window, it **takes
over `aux` and gives it back**.

```text
<leader>va   assembly replaces whatever the *other* pane was showing
  q          the file returns, cursor and scroll restored
<leader>va   toggles it off too
```

**Source left, output right — always.** Direction carries meaning: source is what you
wrote and assembly is what it became, so they read the way a compiler pipeline does.

Standing in the right-hand pane used to flip that, because the target was "the pane
that is not yours". Now the two swap instead: your file moves left with its cursor and
scroll, whatever was on the left moves right, and the right pane is what gets borrowed.
Releasing gives that file back, so both files survive — just on opposite sides.

Asking for `aux` by name was the version before that, and broke whenever the cursor was
already in `aux`: the pane read as taken, a third window got made, and the two panes you
were reading each lost a third of their width.

Nothing shifts along, nothing to hunt for. Assembly appears where your second file was.
Slots are re-derived from what is on screen, left to right, before anything reads them.
Tags drift — a pane gets closed, a borrow is abandoned, a plugin opens a window — and
once they have drifted, `main` and `aux` stop meaning what you see, so `<leader>wa`
lands somewhere different each time. `<leader>wz` is idempotent for the same reason:
running it three times gives the same two panes, not four.

Two kinds of borrow, and the difference matters:

|                           | Released by        | Why                                                                                                                         |
| ------------------------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| **transient** — navbuddy  | leaving the window | you pick a symbol and you are done                                                                                          |
| **linked** — assembly, IR | `q` only           | reading assembly means moving between source and output constantly; one that vanished when you looked away would be useless |

A borrowed pane sets `winfixbuf` so nothing wanders into it while it is lent out. The
release lifts that first — it is the one buffer switch that has to be allowed.

## State is derived, never remembered

A window can be closed by `:q`, by `<C-w>c`, by edgy re-laying the screen, or by a
plugin that split over it — and none of those tell us. A remembered "still open" then
makes the next press close a view that is not there, which reads as **the key having
stopped working**.

So nothing here caches a boolean:

| Question                | Answered by                                            |
| ----------------------- | ------------------------------------------------------ |
| is the layout expanded? | counting content panes                                 |
| is this view showing?   | is its window still valid and still showing its buffer |
| what is in the dock?    | which panel actually has a window                      |
| is `aux` lent out?      | the loan list, reconciled against live windows         |

A `WinClosed` hook releases a borrow when its pane is closed by anything other than us,
so the file it displaced still comes back — **scheduled**, not immediate: `WinClosed`
runs under a textlock, and setting a buffer in a window from there fails with
`E788: Not allowed to edit another buffer now`, taking edgy's layout pass down with it.

A borrow that had to _create_ its pane closes it again on release, rather than restoring
the buffer it was seeded with. Restoring left a second copy of the file you were already
reading, in a pane you never asked for — and that leftover pane then made the toggle
refuse to reopen.

## The dock

Six things want the bottom edge — a terminal, the debugger, the debuggee's output,
diagnostics, quickfix, test output — and edgy will happily stack all of them. The
result is a crowded strip where you hunt for the one you meant.

So the dock holds **exactly one** view. Opening another puts the current one away and
remembers it, which makes `<leader>wb` mean "back to what I had" rather than "close
everything and start again".

| View        | Opened by                                    |
| ----------- | -------------------------------------------- |
| terminal    | `<leader>iT`, or `<leader>wd`                |
| debug       | starting a DAP session, or `<leader>iD`      |
| diagnostics | `<leader>id`                                 |
| quickfix    | a refactoring's conflicts, `:Trouble qflist` |
| tests       | `<leader>in`                                 |

It also replaced a `solo` flag that expanded to `:only` — closing every window in the tab,
**editor panes included**, to make room for a panel at the bottom. Starting a debug
session destroyed the layout you had built. Now only the other dock occupants make way:

```text
before debug: editors=2
after  debug: editors=2  dock=Debug
after  close: editors=2  dock=nil
```

## Outline

One symbols panel, always on the right. Trouble follows the active buffer by itself, so
once there is exactly one of them it tracks whichever editor window the cursor is in —
move to `aux` and it shows that file's symbols, move back and it follows.

## What is docked, and what is not

A panel earns a permanent slot only if it is worth always knowing where it is.

| Edge   | Panels                                                        |
| ------ | ------------------------------------------------------------- |
| left   | neo-tree                                                      |
| right  | outline, tests                                                |
| bottom | diagnostics, quickfix, terminal, debug, debuggee, test output |

Everything else opens on demand with `:Trouble <mode>` and closes again — which was
always shorter than remembering which of eight letters opened it.

The previous version docked nineteen things, five of which were `dapui_*` filetypes
from nvim-dap-ui, a plugin this config no longer uses. `nvim-dap-view` is **one** panel
with winbar tabs: scopes, breakpoints, watches and threads are sections inside it.

## Project diagnostics

`<leader>iq` is this file; `<leader>iQ` is every file. Servers that can report on files
you never opened are asked to. lua_ls and clangd cannot, so `iQ` also runs
`lua-language-server --check` and `run-clang-tidy` (over `compile_commands.json`) in the
background — spinner in the statusline — and their findings join the list as ordinary
diagnostics. Saving a file clears its batch findings; the live server takes over. See
[`project_check.lua`](./project_check.lua).

## Keys

One key per dock view, each a toggle; a different key swaps the view in the same window.

|              |                                   |
| ------------ | --------------------------------- |
| `<leader>iq` | diagnostics (this file)           |
| `<leader>iQ` | diagnostics (project) + the check |
| `<leader>iT` | terminal                          |
| `<leader>iD` | debugger                          |
| `<leader>in` | test output                       |
| `<leader>ic` | close the dock                    |
