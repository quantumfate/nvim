# Tests

```sh
just test                 # every tests/*_spec.lua
just test-one workspace   # one spec: name, name_spec, or path
just check-project        # the project's own checkers, headless, as JSON lines
```

Exits non-zero on any failure, so `just check` and CI can gate on it.

## Isolation

`run.lua` starts one `nvim --headless -n -i NONE` per spec, up to four at a time (half
the cores, fewer if there are fewer). Each child loads the full config, runs its spec and
streams one JSON line per test to a temp file. The parent merges the results and prints
the report.

Separate processes mean one spec's windows, loans or autocmds cannot fail another, and a
crash takes out only its own spec. A child that segfaults or runs past 300s
(`TEST_TIMEOUT=secs` to change) is reported as a failure naming the spec and the test
it was in, followed by the tail of its output.

Autoformat is off (`vim.g.disable_autoformat`): tests write files, and conform
formatting in `BufWritePre` has segfaulted nvim in `buf_write` during test runs.

Tests within one spec still share an editor, so call `t.reset()` in them.

## Why not busted

These drive a real editor (windows, buffers, autocmds, `winfixbuf`), so they have to
run inside `nvim --headless` with this config loaded. A runner that wants to own the
process is more trouble than the twenty lines in `harness.lua`.

## Writing a spec

Add `tests/<name>_spec.lua`; it is picked up automatically.

```lua
local t = require("tests.harness")

t.describe("group", function()
  t.it("says what should be true", function()
    t.reset()                       -- one window, no scratch buffers, no engine state
    local buf = t.buffer({ "..." }) -- or t.file() when a path is needed
    t.eq(expected, actual, "what went wrong if this fails")
  end)
end)
```

Every test is a bug that actually shipped: a case earns a test by having been wrong
once. Before trusting a new test, reintroduce the bug and watch it go red.

Return early when an external tool or parser is missing, so a clean machine skips
instead of failing:

```lua
if vim.fn.executable("xxd") == 0 then return end
if not pcall(vim.treesitter.language.inspect, "rust") then return end
```

## The keymap guards

Three collisions shipped before these existed: `<leader>rn` hid the prose-aware rename
behind inc-rename, `<leader>id` hid the database picker, `<leader>ie` hid "equalize
windows". None of them error; the key simply does something else.

Runtime cannot see the second kind (two `vim.keymap.set` calls on one key leave one
mapping, and the loser is invisible), so that check reads the source instead, skipping
which-key `group =` labels.
