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
| `<leader>xh` | hex view toggle, written back through `xxd -r`                           |
| `<leader>xk` | checkpatch.pl on this file (kernel tree)                                 |
| `<leader>xm` | get_maintainer.pl for this file                                          |
| `<leader>xc` | jump from `CONFIG_FOO` to its Kconfig entry                              |
| `<leader>xQ` | boot the tree's `bzImage` in QEMU, halted, gdbstub on :1234, `nokaslr`   |
| `<leader>xa` | attach gdb (DAP) to that QEMU with `vmlinux` symbols                     |

Toggles work like `<leader>v`: the same key closes the view.

## Why these

- **Layout** compiles only the current file with the project's recorded flags, so it
  works before anything links. Unused types are kept in DWARF on purpose: the struct
  you are designing is usually not used yet. Other languages read the built binary.
- **`xd` vs `va`**: `va` is what the compiler emitted for one file. `xd` is what ended
  up in the program after cross-file inlining, LTO and linking — the code a crash
  address points into. "Not in the binary" usually means it was inlined away.
- **Stack parsing** knows ASan/UBSan/TSan, valgrind, gdb, Rust, Go, Python, Node and
  Zig. The list starts at the first frame in your project, not in libc.
- **Kernel** helpers only activate inside a tree (`MAINTAINERS` + `Kbuild`) and run
  the tree's own scripts, since those are what a patch is judged by.

Debugging uses gdb's built-in DAP (`gdb -i dap`, gdb ≥ 14); C and C++ also keep
codelldb. perf, strace, ltrace, valgrind, bpftrace, rr and friends are in the toolchain
registry's `sys` group so provisioning installs them.
