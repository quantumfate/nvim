# Language actions

Same key, same question, every language. `:LangInfo` prints what the current buffer
supports.

## Keys

| `<leader>b` build/run |                      | `<leader>v` view |                             |
| --------------------- | -------------------- | ---------------- | --------------------------- |
| `bb`                  | build                | `ve`             | expand macros / preprocess  |
| `br`                  | run                  | `va`             | **assembly**                |
| `bR`                  | run (choose target)  | `vi`             | intermediate representation |
| `bc`                  | check (no codegen)   | `vt`             | syntax tree                 |
| `bo`                  | open build file      | `vh`             | switch to related file      |
| `bi`                  | reload project index | `vs`             | symbol details              |

Tests live in the test group rather than the build group, next to the
runner-agnostic neotest bindings:

|      |                                                    |
| ---- | -------------------------------------------------- |
| `ta` | test, through the language's own runner            |
| `tt` | nearest test, `tf` file, `ts` summary, `to` output |

From the language server, bound when it advertises the method:

|             |                           |
| ----------- | ------------------------- |
| `vc` / `vC` | incoming / outgoing calls |
| `vy` / `vY` | supertypes / subtypes     |

A capability the language cannot answer is **not bound**, so which-key only ever shows
what works here.

## Coverage

|                            | rust                     | c / cpp                      | zig              | lua                        | go                               | python                     |
| -------------------------- | ------------------------ | ---------------------------- | ---------------- | -------------------------- | -------------------------------- | -------------------------- |
| build / run / test / check | cargo                    | make · cmake · ninja · meson | zig build        | luajit · busted · luacheck | go build · run · test · vet      | py_compile · pytest · ruff |
| expand                     | `expandMacro`            | `-E -P`                      | —                | —                          | —                                | —                          |
| assembly                   | `cargo rustc --emit asm` | `-S -masm=intel`             | `-femit-asm`     | luajit `-bl` bytecode      | `-gcflags=-S`                    | `dis` bytecode             |
| IR                         | `view_ir` (MIR/HIR)      | `-emit-llvm`                 | `-femit-llvm-ir` | —                          | `-gcflags=-m` inlining & escapes | —                          |
| tree                       | `syntaxTree`             | clang `-ast-dump`            | —                | `:InspectTree`             | `:InspectTree`                   | `python -m ast`            |
| related                    | parent module            | clangd header ↔ source       | —                | —                          | `x.go` ↔ `x_test.go`             | `x.py` ↔ `test_x.py`       |

Python runs under the project's interpreter: `$VIRTUAL_ENV`, then `.venv`, then conda,
then PATH. neotest and the debugger use the same resolution.

## Why C reads compile_commands.json

Preprocessing or compiling a real source file with default flags produces nonsense,
because it needs the include paths and defines the build system passes. So every C
command reuses the recorded compile command — the same database clangd is already
using — with the output and mode flags stripped. Without one you get a warning and
default flags, which is honest but only useful for a self-contained file.

Generate it with `bear -- make`, cmake's `CMAKE_EXPORT_COMPILE_COMMANDS`, or the
kernel's own `make compile_commands.json`.

## Running

`br` differs by design, because "which binary" has a different answer per ecosystem:

- **rust** opens rust-analyzer's runnables — a workspace has several
- **zig** goes through `build.zig`
- **lua** runs the file under luajit
- **c** finds the ELF files that were actually built, asks which one, and remembers the
  choice per project in `stdpath("state")/lang-run.json`. `bR` picks a different one.
  Not `make run`: plenty of projects have no such target, and a kernel tree does not.

Candidates are found by walking the project three levels deep, skipping `.git`,
`node_modules`, `CMakeFiles` and friends, and checking for the `ELF` magic bytes rather
than just the executable bit — which is what keeps shell scripts and generated cmake
helpers out of the list.

## Zig and comptime

Zig has no preprocessor, but `comptime` is still a compile-time expansion: generics get
instantiated and `inline for` gets unrolled. `ve` shows Debug-mode LLVM IR, which is
where that is visible before the optimiser rewrites it; `vi` shows ReleaseFast, which is
what the optimiser did with it. Two different questions.

`--verbose-air` would be the ideal answer and prints nothing on a release build of the
compiler, which is how every distro ships it. Both IR views are filtered to this
module, plus the debug metadata the kept instructions reference — unfiltered a
`build-obj` emit is a third of a million lines, because it contains all of std.

### Module flags

`@import("mylib")` only resolves with the arguments build.zig assembles, so a one-off
`zig build-obj` of a file in a module project fails on the import. The build runner's
`--verbose` prints every compile command before running it, cached or not, which is the
build graph already resolved — including options build.zig computes, which no parse of
build.zig could follow. The views read the `-M<name>=<src>` segments out of it, move the
segment owning this file to the front so its own functions are what gets emitted, and
drop the flags that belong to the build rather than to an emit: the output name and
binary, the optimise mode the view chooses, and `--listen=-`, which makes the compiler
wait on stdin forever.

## Output panes

Views default to the shape of the question. A macro expansion is a glance, so `ve`,
`bc` and the tree views open as a **float**; assembly and IR are something you work
beside, so they open as a **split**.

**One view at a time, and the key that opened it closes it.** Pressing `va` again
closes the assembly; pressing `vi` replaces it with the IR rather than stacking a second
pane. A view is never something you have to find a way out of.

A float takes focus, so `q` and `<Esc>` land where you expect. A split does not — focus
stays in the source so the cursor link works — and `q` inside it, or the key that opened
it, closes it.

Output panes keep the editor background. Tinting them made every rendering look washed
out against the code beside it; the border (floats) and the winbar title (splits) say
"this is a rendering" without dulling a single character. Focus stays in the source, so
actions chain — `va` then `vi` compares the two without moving.

Windows are created with `nvim_open_win`, never `:vsplit`. The command form fires the
whole `WinNew`/`WinEnter`/`BufEnter` chain, edgy re-runs its layout inside it, and that
runs under a textlock — so the buffer swap that follows fails with
`E788: Not allowed to edit another buffer now`.

### Linked cursor

Assembly and IR are compiled with `-g` and the `.loc` / `!dbg` markers are read to build
a row-to-line map, then dropped from the display. Move in the source and the output
follows, with every instruction that line produced highlighted; move in the output and
the source follows.

`<CR>` crosses between the two, in either direction, while the view is on screen; once
it closes, `<CR>` in the source is ordinary again.

Only these two views have a mapping to follow — a preprocessed file or an AST dump has
no line correspondence to the original.

Assembler directives are stripped; symbol boundaries are kept, and the `.debug_*`
sections that come with `-g` are dropped wholesale — DWARF string tables are hundreds
of lines and the `.loc` markers are the only part worth having. Zig emits one `.file` per
standard-library module, which is hundreds of lines before the first instruction.

Rust and zig compile a whole crate or module graph, so the assembly is then narrowed to
the blocks that contain an instruction carrying one of _this file's_ `.loc`s. That is
what drops the per-crate apparatus a label-only block is made of — exception tables,
personality references, string tables — along with every function the rest of the graph
contributed. A single-file compile has nothing to filter and keeps everything.

### Background jobs

`vim.system` keeps the editor usable while a compile runs, which also means a slow
`cargo rustc` looks exactly like a keypress that did not register. So every background
command registers with `features/lang/jobs.lua` and the statusline shows a spinner:

```text
 normal   main   rust  ⠙ rust asm 6s     3  1:1  All/36  bacon_ls
```

The elapsed count only appears after two seconds — a number that starts at 0 on every
keypress is noise. `:LangJobs` lists everything running.

The notification that used to fire per invocation is gone: it was noise for the fast
commands and gone before you read it on the slow ones.

### Highlighting

`asm`, `llvm`, `objdump` and `disassembly` are in the treesitter `ensure_installed`
list. Without those parsers the output arrives as plain text, which is the hardest
possible way to read a disassembly.

## Adding a language

Write `lua/features/lang/<filetype>.lua` returning a table with any of the capability
names above. Anything omitted is simply unbound.
