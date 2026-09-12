# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### M5 · Headless & scriptable

- Added headless commands with machine-readable JSON output: `:ProjectCheckJson`, `:SysPatchJson`, `:SysTrace`, and headless workspace runner (`lua/features/workspace/headless.lua`).
- Added `just check-project` and task recipes in `justfile`.
- Automated CI validation with Codeberg/Forgejo actions.

### M4 · Kernel workflow

- Verified kernel helpers (`checkpatch.pl`, `get_maintainer.pl`, `Kconfig` symbol jumps) against real upstream Linux tree.
- Implemented `lua/features/sys/patch.lua` for `b4` patch series management (`prep`, cover letter buffer editing on save, `b4 trailers -u`, series checkpatch to quickfix, dry-run send reviews).
- Resolved kernel module (`.ko`) oops frames in `:CrashDecode` with section-relative symbol arithmetic and batched `addr2line`.
- Tuned `clangd` at kernel scale with low-priority indexing, bounded results, and in-memory compilation database caching.
- Supported kernel image candidate resolution and auto-loading `vmlinux-gdb.py` in QEMU DAP debugging.

### M3 · Change code safely

- Multi-crate Cargo workspace support for trait refactoring (`add_param`, `remove_param`, `reorder_param`) across crate boundaries.
- Integrated `rust-analyzer/runFlycheck` on save to catch compiler errors like E0050.
- Live TypeScript verification against `ts_ls` for overload signatures, class constructors, and `.apply` call skips with `tsc --noEmit` validation.
- Python class hierarchy traversal and override synchronization.
- Refusal of nested parameter list edits and macro definition conflicts.

### M2 · Read the machine

- Go struct layout inspection and formatting.
- Perf per-function instruction annotation and flamegraph folding.
- Strace per-thread views, class filtering, and execution summary.
- Bpftrace probe templates with child and pid attachments.
- Integrated `rr` record and replay with `kernel.perf_event_paranoid` verification and DAP configuration.
- Project check diagnostic collection across Rust (`clippy`), Go (`vet`), and TypeScript (`tsc`).

### M1 · Trustworthy core

- Isolated test runner (`tests/run.lua`) running one `nvim --headless` process per spec.
- Zero-warning clean `lua_ls` codebase analysis across config and tests.
- Verified C scaffolding build and test automation across CMake, Meson, and Make.
- Theme switching and monotonic luminance ramp guard across adapted and unadapted colorschemes.
- Continuous integration gating via `just check`.
