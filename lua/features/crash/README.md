# Crash inspection

A segfault is a stack trace pointing at your source, which is the kind of thing an
editor should be able to open.

|                                        |                                                      |
| -------------------------------------- | ---------------------------------------------------- |
| `<leader>dc`                           | pick a recent core dump from your own binaries       |
| `<leader>dC`                           | pick from every captured dump                        |
| `:Crashes[!]`                          | the same, `!` widens to all binaries                 |
| `:CrashOpen <core> [exe]`              | a core file by path, for one systemd did not capture |
| `:CrashDecode [vmlinux] [modules_dir]` | symbolise a kernel oops in the current buffer        |

In a report: `<CR>` or `gf` jumps to the frame's source, `D` opens the same dump in an
interactive gdb, `q` closes.

## Why gdb and not just coredumpctl

`coredumpctl info` gives frames like

```text
#0  0x0000558436cca1cc deref (crash + 0x11cc)
```

A symbol and an offset — nothing you can act on. The same frame through gdb:

```text
#0  0x0000558436cca1cc in deref (s=0x0) at crash.c:7
```

which names the faulting line _and_ the argument that caused it. So gdb symbolises and
this module navigates. Without gdb installed the report still opens, with a note saying
frames have no source locations.

`bt full` is used rather than `bt`, because the locals are usually where the answer is.

## Finding the source

gdb records the path the binary was compiled with, which is often relative or points at
a build directory that no longer exists. Frames resolve by trying, in order: the exact
path, the same name beside the executable, then a search downward from the executable's
directory. That is what makes a frame jumpable for a binary built somewhere else.

## Kernel oops

An oops names a symbol and an offset:

```text
RIP: 0010:my_driver_probe+0x47/0x120
```

`:CrashDecode` reads the symbol table with `readelf`, adds the offset to the symbol's
address, and asks `addr2line` for the location — the same thing the kernel's
`scripts/decode_stacktrace.sh` does, without needing the build tree.

Results are attached as **virtual text**, not written in: the buffer is a log, and a log
that has been edited is no longer evidence.

The `vmlinux` must match the kernel that crashed, or nothing resolves and it says so.
Searched automatically:

```text
./vmlinux
/usr/lib/debug/boot/vmlinux-$(uname -r)
/usr/lib/modules/$(uname -r)/build/vmlinux
/boot/vmlinux-$(uname -r)
```

Pass one explicitly when working on a tree you just built:
`:CrashDecode ~/src/linux/vmlinux`.

## Requirements

`coredumpctl` for the picker, `gdb` for source locations, `binutils` (`addr2line`,
`readelf`) for oops decoding. Core dumps must actually be captured — check
`/proc/sys/kernel/core_pattern` points at `systemd-coredump`, and `ulimit -c` is not 0.
