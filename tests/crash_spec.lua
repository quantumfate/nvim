--- Regression tests for the crash tooling and the stack parser, from the bug hunt that
--- ran them against real core dumps, sanitizer reports and oops texts.
local t = require("tests.harness")
local kernel = require("features.crash.kernel")
local report = require("features.crash.report")
local stack = require("features.sys.stack")

t.describe("crash kernel", function()
	t.it("adds offsets to 64-bit addresses exactly", function()
		-- As a double this came out as …8800, and every decode landed in the wrong function.
		t.eq("0xffffffff81268c0d", kernel.add_offset("ffffffff81268ba0", 0x6d))
		t.eq("0xffffffff82000000", kernel.add_offset("ffffffff81ffffff", 1), "carry across the halves")
		t.eq("0x0000000000001010", kernel.add_offset("0x1000", 0x10))
	end)

	t.it("marks module and unreliable frames", function()
		local frames = kernel.frames({
			"[   12.345678]  my_probe+0x47/0x120 [my_mod]",
			"[   12.345679]  ? do_one_initcall+0x5a/0x300",
			"RIP: 0010:exc_page_fault+0x7f/0x180",
		})
		t.eq(3, #frames)
		t.eq("my_mod", frames[1].module)
		t.eq(true, frames[2].unreliable)
		t.eq(nil, frames[3].module)
		t.eq(0x7f, frames[3].offset)
	end)

	t.it("does not count ??:? as resolved", function()
		t.eq(nil, kernel.parse_location("handle_stack_overflow at ??:?"))
		t.eq(nil, kernel.parse_location("?? ??:0"))
		t.eq("show_regs at arch/x86/kernel/dumpstack.c:489", kernel.parse_location("show_regs at arch/x86/kernel/dumpstack.c:489"))
	end)
end)

t.describe("crash report", function()
	t.it("parses Go, Zig and generic frames, once each", function()
		local lines = {
			"Program terminated with signal SIGSEGV, Segmentation fault.",
			"#0  0x0000555555555139 in main () at /src/null.c:4",
			"#0  0x0000555555555139 in main () at /src/null.c:4",
			"#13 0x000000000049ab12 in main.get (t=<optimized out>) at /src/main.go:6",
			"#8  0x0000000001034abc in main.main () at /src/main.zig:8",
			"#4  std::sys::backtrace::__rust_end_short_backtrace<std::panicking::begin_panic::{closure_env#0}<&str>, !> () at /rustc/abc/library/std/src/sys/backtrace.rs:168",
			"#12 rseg::poke (p=0x0) at /src/rseg/src/main.rs:2",
			"#5  0x00007ffff7c27c8e in __libc_start_call_main () from /usr/lib/libc.so.6",
		}
		local frames = report.parse_frames(lines)
		local by_func = {}
		for _, f in pairs(frames) do
			by_func[f.func] = (by_func[f.func] or 0) + 1
		end
		t.eq(1, by_func["main"], "the repeated frame #0 was kept twice")
		t.eq(1, by_func["main.get"])
		t.eq(1, by_func["main.main"])
		t.eq(1, by_func["rseg::poke"])
		t.eq(5, vim.tbl_count(frames), "a frame without a source location was parsed")
	end)

	t.it("opens on the program's own frame, and marks the innermost as the fault", function()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		vim.fn.writefile({ "fn main() {}" }, dir .. "/main.rs")
		local frames = report.parse_frames({
			"#3  std::sys::pal::unix::abort_internal () at /rustc/abc/library/std/src/sys/pal/unix/mod.rs:370",
			"#12 rseg::poke (p=0x0) at " .. dir .. "/main.rs:1",
		})
		local landing, fault = report.landing(frames, dir)
		t.eq(2, landing, "landed in the runtime")
		t.eq(1, fault)
	end)

	t.it("keeps the warnings that say the symbols are wrong", function()
		local cleaned = report.clean({
			"warning: Can't read data for section '.note' in file 'x'",
			"warning: File /tmp/bin/null doesn't match build-id from core-file",
			"Enable debuginfod? (y or [n]) [answered N; input not from terminal]",
			"#0  main () at /src/null.c:4",
		})
		t.ok(table.concat(cleaned, "\n"):find("build%-id"), "the build-id mismatch was hidden")
		t.ok(not table.concat(cleaned, "\n"):find("debuginfod"), "gdb chatter survived")
	end)
end)

t.describe("crash stack parser", function()
	t.it("reads TSan frames", function()
		local items = stack.parse({
			"WARNING: ThreadSanitizer: data race (pid=2202)",
			"    #0 main /src/race.c:10:9 (race+0x11cada) (BuildId: 58f2ab)",
		}, {})
		t.eq({ "/src/race.c", 10, "main" }, { items[2].filename, items[2].lnum, items[2].text })
	end)

	t.it("labels gdb frames #10 and up with the function, not its arguments", function()
		local items = stack.parse({ "#10 0x0000000000475e79 in runtime.gopanic (e=...) at /usr/lib/go/src/runtime/panic.go:878" }, {})
		t.eq("runtime.gopanic", items[1].text)
		t.eq(878, items[1].lnum)
	end)

	t.it("handles Python SyntaxError and frozen frames", function()
		local items = stack.parse({
			'  File "<frozen runpy>", line 294, in _run',
			'  File "/src/bad.py", line 2',
		}, {})
		t.eq(0, items[1].valid, "<frozen runpy> should not be an openable entry")
		t.eq({ "/src/bad.py", 2 }, { items[2].filename, items[2].lnum })
	end)

	t.it("takes the function name from the line above for Rust and Go", function()
		local items = stack.parse({
			"   3: rpanic::inner",
			"             at /src/main.rs:4:5",
			"main.get(0x0)",
			"\t/src/main.go:6 +0x1d",
			"\t/usr/lib/go/src/runtime/asm_amd64.s:1264 +0x1",
		}, {})
		t.eq("rpanic::inner", items[1].text)
		t.eq("main.get", items[2].text)
		t.eq("/usr/lib/go/src/runtime/asm_amd64.s", items[3].filename)
	end)

	t.it("does not guess between two files with the same name", function()
		local root = vim.fn.tempname()
		vim.fn.mkdir(root .. "/a/src", "p")
		vim.fn.mkdir(root .. "/b/src", "p")
		vim.fn.writefile({}, root .. "/a/src/main.rs")
		vim.fn.writefile({}, root .. "/b/src/main.rs")
		local items = stack.parse({ "thread 'main' panicked at src/main.rs:2:14:" }, { root = root })
		t.eq("src/main.rs", items[1].filename, "picked one of two main.rs")
	end)

	t.it("a sibling directory with a longer name is not the project", function()
		local items = stack.parse({ "    #0 0x1 in f /p/proj2/x.c:1:1" }, { root = "/p/proj" })
		t.eq(false, items[1].own)
	end)
end)
