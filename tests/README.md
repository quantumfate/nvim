# Tests

```sh
just test          # or: nvim --headless -c 'luafile tests/run.lua'
```

Exits non-zero on failure, so `just check` and pre-commit can gate on it.

## Why not busted

These drive a real editor — windows, buffers, autocmds, `winfixbuf` — so they have to
run inside `nvim --headless` with this config loaded. A runner that wants to own the
process is more trouble than the twenty lines in `harness.lua`.

## What is covered

Every test is a bug that actually shipped. That is the entry criterion: a case earns a
test by having been wrong once.

| Spec             | Regression                                                                                                                                                                                                  |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `workspace_spec` | panes multiplying; a rendering not counted against the two-pane limit; output landing left of the source; a borrow losing a file; `winfixbuf` blocking its own restore; a layout key that only went one way |
| `refactor_spec`  | half-applied refactorings; undo discarding later edits; `mut x: i32` read as a parameter named `mut`; prose rename rewriting English                                                                        |
| `lang_spec`      | `.loc` markers dropped before the cursor map was built; DWARF sections in the assembly; a capability with no title silently not toggling; import paths                                                      |

## The keymap guards

Three collisions shipped before these existed. `<leader>rn` hid the prose-aware rename
behind inc-rename, `<leader>id` hid the database picker, `<leader>ie` hid "equalize
windows". None of them error — the key simply does something else, and you find out
weeks later.

Runtime cannot see the second kind: two `vim.keymap.set` calls on one key leave one
mapping, and the loser is invisible. So that check reads the source instead, skipping
which-key `group =` labels — `<leader>w` is a group _and_ the prefix of a dozen real
bindings.

## Adding one

```lua
t.describe("group", function()
  t.it("says what should be true", function()
    t.reset()                       -- one window, no scratch buffers
    local buf = t.buffer({ "..." }) -- or t.file() when a path is needed
    t.eq(expected, actual, "what went wrong if this fails")
  end)
end)
```

`t.reset()` clears engine state — outstanding loans, remembered views — before it
touches windows. A loan left behind by one spec made the _next_ one fail, in a file that
had nothing to do with it.

`t.reset()` at the top of anything that touches windows — otherwise one test's layout
becomes the next one's starting state, and the failure appears in the wrong place.

## Checking a test can fail

A green suite proves nothing until a test has been seen to go red. Reintroduce the bug,
run, and confirm the count:

```text
21 passed, 1 failed, 22 total
FAIL workspace › counts a rendering as a content pane
```

---

Issues: [Linear](https://linear.app/quantumfate/project/neovim-configuration-382d73d48a3b), label `Module › tests`.
