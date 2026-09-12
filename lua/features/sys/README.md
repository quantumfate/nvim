# sys

What the machine actually does with your code. Every tool reads the program that
already knows: pahole, nm, objdump, addr2line, checkpatch.pl, QEMU, gdb. `:SysInfo`
lists the keys and what each one is missing.

| Key          | Does                                                                     |
| ------------ | ------------------------------------------------------------------------ |
| `<leader>xl` | struct layout under the cursor: offsets, holes, cache lines (pahole)     |
| `<leader>xe` | ELF symbols by size; `<CR>` jumps to source, `d` disassembles            |
| `<leader>xd` | the function under the cursor, disassembled **from the linked binary**   |
| `<leader>xr` | run the binary with loud sanitizers/backtraces; frames go to quickfix    |
| `<leader>xq` | any stack trace in the current buffer (a terminal, a log) to quickfix    |
| `<leader>xp` | perf profile: `▮ 76.4%` at the end of hot lines, quickfix hottest first  |
| `<leader>xf` | perf annotate of the function under the cursor, cursor-linked to source  |
| `<leader>xs` | strace log; failed calls in red, `<CR>` jumps to the line that made them |
| `<leader>xb` | bpftrace probe on the binary: syscall latency, off-CPU, faults, malloc   |
| `<leader>xh` | hex view toggle, written back through `xxd -r`                           |
| `<leader>xk` | checkpatch.pl on this file (kernel tree)                                 |
| `<leader>xm` | get_maintainer.pl for this file                                          |
| `<leader>xc` | jump from `CONFIG_FOO` to its Kconfig entry                              |
| `<leader>xS` | sparse on this file (`:Sparse`): endianness, `__user`, bitwise misuse    |
| `<leader>xC` | coccinelle script in report mode over this file (`:Coccicheck [file]`)   |
| `<leader>xQ` | boot the tree's `bzImage` in QEMU, halted, gdbstub on :1234, `nokaslr`   |
| `<leader>xa` | attach gdb (DAP) to that QEMU with `vmlinux` symbols                     |

Toggles work like `<leader>v`: the same key closes the view.

## Why these

- **Layout** compiles only the current file with the project's recorded flags, so it
  works before anything links. Unused types are kept in DWARF on purpose: the struct
  you are designing is usually not used yet. Rust and Zig read the built binary. Go has
  none of this: its linker keeps DWARF only for types the runtime needs, so the layout
  comes from a generated test injected with `-overlay` and asked for `reflect`'s own
  offsets — the compiler that built the test is the one that laid the struct out.
- **`xd` vs `va`**: `va` is what the compiler emitted for one file. `xd` is what ended
  up in the program after cross-file inlining, LTO and linking — the code a crash
  address points into. "Not in the binary" usually means it was inlined away.
- **Stack parsing** knows ASan/UBSan/TSan, valgrind, gdb, Rust, Go, Python, Node and
  Zig. The list starts at the first frame in your project, not in libc.
- **perf**: `xp` keeps its recording, so `xf` annotates the same run until the binary
  is rebuilt. `:SysFlame` records with DWARF call graphs, folds `perf script` in Lua
  into `stdpath("cache")/sys-flame/<bin>.folded`, and renders an SVG when
  `inferno-flamegraph` or `flamegraph.pl` is installed.
- **strace** groups threads under a `pid` header (a fold each) and joins
  `<unfinished ...>` with its `resumed>` half. In the log, `S` shows `strace -c` (time
  and errors per syscall), `F` re-runs filtered to a class (`%file`, `%network`,
  `%memory`, `%process`, ...). `:SysStrace [summary] [class]` does the same.
- **bpftrace** runs the binary under `-c`, or attaches to a running instance for 10s.
  It needs root: passwordless `sudo -n` runs it into a view, otherwise a terminal
  runs the `sudo bpftrace ...` command so the password prompt is yours.
- **sparse and coccinelle** run through the tree's own build (`make C=2 <file>.o`,
  `make coccicheck MODE=report M=<dir>`), so the file is checked with the flags it is
  really compiled with; `xC` picks from `scripts/coccinelle`. Outside a tree, `xS` uses
  the file's `compile_commands.json` flags and `xC` asks for a `.cocci` path. Findings
  go to quickfix; `C=2` not `C=1`, which skips files it does not recompile.
- **Kernel** helpers only activate inside a tree (`MAINTAINERS` + `Kbuild`) and run
  the tree's own scripts, since those are what a patch is judged by.

Debugging uses gdb's built-in DAP (`gdb -i dap`, gdb ≥ 14); C and C++ also keep
codelldb. perf, strace, ltrace, valgrind, bpftrace, rr and friends are in the toolchain
registry's `sys` group so provisioning installs them.

The tools reuse the binary `<leader>br` remembers; `<leader>bR` picks another.

Two installed tools are deliberately not wired, because they do not work here:

- **valgrind** dies with SIGILL inside the dynamic loader: CachyOS builds glibc with
  AVX-512, which valgrind cannot emulate. ASan (`<leader>xr`) covers the same bugs.
- **rr** needs `kernel.perf_event_paranoid ≤ 1` and, on Zen CPUs, the SpecLockMap
  workaround from rr's wiki.
