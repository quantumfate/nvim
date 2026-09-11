# Refactoring engine

Every refactoring builds a `refactor.Plan` and applies none of it. Preview, conflict
gating and cross-file undo are shared, so a new refactoring is the analysis and
nothing else.

```text
op.run()
  └─ analyse ──> Plan { edits, conflicts, skips }
                   ├─ preview.open()   <CR> apply · q abort · <Tab> jump
                   └─ plan:apply()     conflicts block · snapshots taken
                                        └─ :RefactorUndo  restores every file at once
```

## Ops

| Key                 | Op                                     | Needs            |
| ------------------- | -------------------------------------- | ---------------- |
| `<leader>rr`        | menu                                   | —                |
| `<leader>ra` / `rA` | add parameter (`rA` forces call sites) | LSP + treesitter |
| `<leader>rx`        | remove parameter                       | LSP + locals     |
| `<A-n>` / `<A-d>`   | move parameter right / left            | LSP + treesitter |
| `<leader>rn`        | rename, incl. comments and strings     | LSP              |
| `<leader>rs`        | safe delete                            | LSP              |
| `<leader>rv`        | extract variable (visual)              | locals           |
| `<leader>ri`        | inline variable                        | locals           |
| `<leader>rm`        | move to file                           | treesitter       |
| `<leader>rS`        | server refactorings                    | LSP code actions |
| `<leader>ru`        | undo last refactoring, all files       | —                |

`:Refactor [op]` and `:RefactorUndo` do the same from the cmdline.

`<leader>rv` and `<leader>ri` stay with refactoring.nvim, which binds them
buffer-locally and drives them with motions. This engine's plan-based versions add a
preview and collision checks but take no motion, so they live on `:Refactor` rather
than fighting for the key. `<leader>rr` is the one menu for both.

## Three sources of truth

| Source          | Knows                                 | Used for                          |
| --------------- | ------------------------------------- | --------------------------------- |
| language server | resolved references, workspace rename | call sites, rename, safe delete   |
| `locals.scm`    | scopes and bindings                   | name collisions, extract, inline  |
| treesitter      | syntax                                | parameter lists, function extents |

`locals.scm` is why extract and inline work with no server running, in every language
`queries/*/locals.scm` covers.

## Files

| File          | Holds                                        |
| ------------- | -------------------------------------------- |
| `plan.lua`    | the Plan type, atomic apply, cross-file undo |
| `preview.lua` | the confirm-before-apply window              |
| `locals.lua`  | scope model over `locals.scm`                |
| `usages.lua`  | LSP references + comment/string occurrences  |
| `syntax.lua`  | shared treesitter helpers                    |
| `langs.lua`   | per-language signature facts                 |
| `ops/`        | one file per refactoring                     |

## Safety

| Guard                        | What it stops                                                                                                  |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------- |
| conflicts block apply        | removing a parameter still used, deleting a referenced symbol                                                  |
| `:RefactorUndo` checks first | refuses when a file changed since the refactoring, so it cannot discard later work. `:RefactorUndo!` overrides |
| one at a time                | a second refactoring cannot interleave into the first one's plan                                               |
| write-back is scoped         | only files the engine opened are written; files you had open stay dirty for review                             |

## Rename and prose

LSP rename handles the identifiers. The comment and string pass on top is **additive**:
turn it off and the rename is still complete and correct, it just leaves stale
comments.

It matches only where the text reads as a symbol — `area()`, `M.area`, `` `area` ``,
`@param area` — never bare English, so renaming `area` leaves "Computes the area of a
rectangle" alone while fixing "Call `area()`". Pass `prose = false` to skip it, or
`prose = "loose"` for every whole-word hit.

## Knowing what was not checked

A guard that found nothing and a guard that never ran look identical from the outside,
and only one of them is reassuring. So "did not run" is a recorded outcome, shown in
the preview beside the conflicts:

```text
Left alone
  t.zig:3  no language server; call sites untouched

Not checked
  collision detection — no locals query for zig
  imports — not written automatically for zig
```

The same applies after apply: a refactoring that could not be verified says so rather
than staying quiet, since silence would read as "verified and clean".

`:checkhealth refactor` prints the whole matrix — which of signature, locals,
visibility and imports covers each filetype — so coverage is knowable before starting
rather than mid-refactor.

## Verification

Type-level breakage cannot be predicted from treesitter — but it does not have to be.
After the edits land, the server re-analyses and any new error or warning is reported
against a baseline taken beforehand:

```text
Remove parameter b (introduced problems)
  Undefined global `b`.
  This function expects a maximum of 1 argument(s) but instead it is receiving 2.
```

Both come from the server's type information, not from this engine. Warnings count:
lenient servers rank exactly these at WARN. Turn it off per call with `verify = false`.

## Imports

`move_to_file` writes the import for languages whose import form is a rule — Lua
(dotted module under `lua/`) and JS/TS (relative path). Everything else reports a skip
rather than guessing. Names the moved code used but did not define are reported too,
since they have to travel with it.

## Ceiling, and who covers it

Extract interface, pull member up and anything else needing resolved types cannot be
computed from treesitter. But they are not out of reach — they are just **somebody
else's job**, and for a language with a mature server that somebody already did it.

`<leader>rS` hands the cursor to the language server's own assists. In a Cargo project
that is rust-analyzer, which offers roughly a hundred of them:

| Where the cursor is | What it offers                                                                |
| ------------------- | ----------------------------------------------------------------------------- |
| `impl Shape`        | Generate trait from impl — extract interface, working                         |
| `struct Shape`      | Convert to tuple struct, Generate `new`, Add `#[derive]`, Generate trait impl |
| a `let` binding     | Insert explicit type, Replace let with if let                                 |
| a function          | Inline into all callers                                                       |

So the division is: this engine owns the refactorings that are the same everywhere
(signatures, renames, extract, move) across every language it has a grammar for, and
defers the type-level ones to whoever modelled that language properly. For Rust that
is rustaceanvim and rust-analyzer; for Java it would be jdtls. For Lua and Zig nothing
implements them, and that menu is genuinely short — which is the honest answer rather
than a gap to apologise for.

The menu is **unfiltered on purpose**. `only = { "refactor" }` reads as correct and
silently hides most of what is on offer, because rust-analyzer sends many assists with
no `kind` at all — including "Generate trait from impl".

## Adding a refactoring

Add an entry to `M.ops` in `init.lua` and a file under `ops/`. Build a plan, record
conflicts for anything unsafe and skips for anything merely unhandled, then call
`signature.finish(plan, opts)`. Preview and undo come free.
