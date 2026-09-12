--- perf annotate, flamegraph folding, strace grouping and summaries, bpftrace commands.
--- Samples are trimmed from real perf 7.2, strace 7.0 and bpftrace 0.26 output, run on
--- a small threaded C program.
local t = require("tests.harness")
local profile = require("features.sys.profile")
local trace = require("features.sys.trace")
local bpf = require("features.sys.bpf")
local output = require("features.lang.output")

t.describe("sys perf annotate", function()
	t.it("reads per-instruction percentages and perf's own locations", function()
		local ins = profile.parse_annotate({
			"",
			"Sorted summary for file /tmp/nvim-sys-tools/hot",
			"----------------------------------------------",
			"",
			"   95.63 hot.c:10",
			"    4.37 hot.c:9",
			" Percent |\tSource code & Disassembly of hot for cpu/cycles/Pu (300 samples, percent: local period)",
			"-------------------------------------------------------------------------------------------------------",
			"         :",
			"         : 5    00000000000011c0 <mix>:",
			"    0.00 :   11c0:   mov    %rdi,%rax",
			"    0.00 :   11e0:   imul   %rsi,%rax",
			"   95.63 :   11e4:   add    %rcx,%rax // hot.c:10",
			"    4.37 :   11e7:   sub    $0x1,%edx // hot.c:9",
			"    0.00 :   11ea:   jne    11e0 <mix+0x20>",
			"    0.00 :   11ec:   ret",
		})
		t.eq(6, #ins, "the sorted summary or the symbol header was taken for an instruction")
		t.eq({ pct = 95.63, addr = "11e4", text = "add    %rcx,%rax", loc = "hot.c:10" }, ins[3])
		t.eq({ pct = 0, addr = "11ea", text = "jne    11e0 <mix+0x20>" }, ins[5])
	end)

	t.it("maps rows to this file's lines and records heat", function()
		local ins = {
			{ pct = 0, addr = "11c0", text = "mov" },
			{ pct = 95.63, addr = "11e4", text = "add" },
			{ pct = 0, addr = "11f0", text = "inlined" },
		}
		local rows, map, heat = profile.annotate_rows("mix", ins, {
			{ filename = "/src/hot.c", lnum = 11 },
			{ filename = "/src/hot.c", lnum = 10 },
			{ filename = "/usr/include/string.h", lnum = 40 },
		}, "/src/hot.c")
		t.eq(5, #rows)
		t.eq({ [3] = 11, [4] = 10 }, map, "a header's line numbers would move the cursor in hot.c")
		t.eq({ [4] = 95.63 }, heat)
		t.ok(rows[4]:find("95.63%", 1, true) and rows[4]:find("hot.c:10", 1, true))
	end)

	t.it("lists user-space symbols from perf report --sort sym", function()
		t.eq(
			{ { pct = 57.76, name = "main" }, { pct = 39.61, name = "worker" }, { pct = 0, name = "usleep" } },
			profile.parse_symbols({
				"# Overhead  Symbol",
				"    57.76%  [.] main",
				"    39.61%  [.] worker",
				"     2.62%  [k] 0xffffffffa3e015f0",
				"     0.00%  [.] usleep",
			})
		)
	end)
end)

t.describe("sys flamegraph folding", function()
	t.it("folds perf script samples root first, weighted by period", function()
		local folded = profile.fold({
			"hot  439457 47745.667173:          1 cpu/cycles/Pu: ",
			"\t    7f98273abb74 [unknown] (/usr/lib/ld-linux-x86-64.so.2)",
			"",
			"hot  444626 47783.042754:    4308884 cpu/cycles/Pu: ",
			"\t    55aac8bbc1e4 mix+0x24 (/tmp/nvim-sys-tools/hot)",
			"\t    55aac8bbc21c work+0x2f (/tmp/nvim-sys-tools/hot)",
			"\t    55aac8bbc2ed main+0x78 (/tmp/nvim-sys-tools/hot)",
			"\t    7fe26cc27c8d [unknown] (/usr/lib/libc.so.6)",
			"\t    7fe26cc27dca __libc_start_main_impl+0x8a (inlined)",
			"\t    55aac8bbc0c4 _start+0x24 (/tmp/nvim-sys-tools/hot)",
			"",
			"hot  444626 47783.043736:          6 cpu/cycles/Pu: ",
			"\t    55aac8bbc1e4 mix+0x24 (/tmp/nvim-sys-tools/hot)",
			"\t    55aac8bbc21c work+0x2f (/tmp/nvim-sys-tools/hot)",
			"\t    55aac8bbc2ed main+0x78 (/tmp/nvim-sys-tools/hot)",
			"\t    7fe26cc27c8d [unknown] (/usr/lib/libc.so.6)",
			"\t    7fe26cc27dca __libc_start_main_impl+0x8a (inlined)",
			"\t    55aac8bbc0c4 _start+0x24 (/tmp/nvim-sys-tools/hot)",
			"",
			"hot  439458 47745.667540:       7552 cpu/cycles/Pu: ",
			"\tffffffffa3e01280 [unknown] ([unknown])",
			"\t    5559987d026a worker+0x28 (/tmp/nvim-sys-tools/hot)",
		})
		t.eq({
			"hot;[ld-linux-x86-64.so.2] 1",
			"hot;_start;__libc_start_main_impl;[libc.so.6];main;work;mix 4308890",
			"hot;worker;[unknown] 7552",
		}, folded)
	end)
end)

t.describe("sys strace threads and summary", function()
	t.it("joins unfinished calls with their resumed half, per pid", function()
		local calls = trace.parse({
			"447794 23:00:28.149524 set_robust_list(0x7fdc55ffc9a0, 24 <unfinished ...>",
			'447793 23:00:28.149529 openat(AT_FDCWD, "/nonexistent/main", O_RDONLY <unfinished ...>',
			"447794 23:00:28.149537 <... set_robust_list resumed>) = 0 <0.000009>",
			"447793 23:00:28.149542 <... openat resumed>) = -1 ENOENT (No such file or directory) <0.000007>",
			" > /usr/lib/libc.so.6(__open64+0x9d) [0x13c28d]",
			" > /src/hot(main+0x4a) [0x12bf]",
			'447794 23:00:28.974056 openat(AT_FDCWD, "/nonexistent/thread", O_RDONLY) = -1 ENOENT (No such file or directory) <0.000009>',
			"447794 23:00:29.109150 +++ exited with 0 +++",
		})
		t.eq(4, #calls, "a resumed half became its own call")
		-- The exit line is a row, not a call: counting it reports one syscall too many.
		t.ok(calls[4].status, "the exit line was counted as a syscall")
		t.eq(
			'openat(AT_FDCWD, "/nonexistent/main", O_RDONLY) = -1 ENOENT (No such file or directory) <0.000007>',
			calls[2].line
		)
		t.eq({ 447793, "openat", "ENOENT" }, { calls[2].pid, calls[2].syscall, calls[2].error })
		t.eq("12bf", trace.own_frame(calls[2], "/src/hot").addr, "the stack after a resumed line lost its call")

		local groups = trace.group(calls)
		t.eq({ 447794, 447793 }, { groups[1].pid, groups[2].pid })
		t.eq({ 3, 2, 1 }, { #groups[1].calls, groups[1].made, groups[1].failed })

		local rows, row_call = trace.render(calls, "hot")
		t.eq("hot — 3 calls, 2 failed", rows[1])
		t.eq("pid 447794 (main) · 2 calls, 1 failed", rows[3])
		t.eq("pid 447793 · 1 calls, 1 failed", rows[8])
		t.eq(calls[2], row_call[9])
	end)

	t.it("a single process has no pid headers", function()
		local rows = trace.render(trace.parse({ '15:28:10.337763 write(1, "hi\\n", 3) = 3 <0.000007>' }), "io")
		t.eq({ "io — 1 calls, 0 failed", "", 'write(1, "hi\\n", 3) = 3 <0.000007>' }, rows)
	end)

	t.it("parses strace -c, with blank error columns", function()
		local rows, total = trace.parse_summary({
			"% time     seconds  usecs/call     calls    errors syscall",
			"------ ----------- ----------- --------- --------- ----------------",
			" 43.89    0.000194         194         1           execve",
			"  6.79    0.000030           7         4         2 openat",
			"  0.00    0.000000           0         1           clock_nanosleep",
			"------ ----------- ----------- --------- --------- ----------------",
			"100.00    0.000442           9        49         3 total",
		})
		t.eq(3, #rows)
		t.eq({ pct = 43.89, seconds = 0.000194, calls = 1, errors = 0, syscall = "execve" }, rows[1])
		t.eq({ pct = 6.79, seconds = 0.00003, calls = 4, errors = 2, syscall = "openat" }, rows[2])
		assert(total)
		t.eq({ 49, 3 }, { total.calls, total.errors })
	end)

	t.it("filters by strace's syscall classes", function()
		t.eq({}, trace.class_args("all"))
		t.eq({ "-e", "trace=%network" }, trace.class_args("network"))
		for _, class in ipairs({ "file", "network", "memory", "process" }) do
			t.ok(vim.tbl_contains(trace.classes, class), class .. " missing from the picker")
		end
	end)
end)

t.describe("sys bpftrace", function()
	---@param name string
	---@return sys.BpfTemplate
	local function template(name)
		for _, tpl in ipairs(bpf.templates) do
			if tpl.name == name then
				return tpl
			end
		end
		error("no template " .. name)
	end

	t.it("scopes a run to the child and an attach to the pid, with an end", function()
		local run = assert(bpf.command(template("syscall latency"), { cmd = "/src/hot" }))
		t.eq({ "bpftrace", "-B", "line", "-c", "/src/hot", "-e" }, vim.list_slice(run, 1, 6))
		t.ok(run[7]:find("sys_enter /pid == cpid/", 1, true), run[7])
		t.ok(not run[7]:find("interval", 1, true), "a -c run ends with the program")

		local attach = assert(bpf.command(template("page faults"), { pid = 4242 }, { seconds = 5 }))
		t.eq({ "-p", "4242" }, vim.list_slice(attach, 4, 5))
		t.ok(attach[7]:find("/pid == 4242/", 1, true))
		t.ok(attach[7]:find("interval:s:5 { exit(); }", 1, true), "an attach would never end")
	end)

	t.it("off-CPU matches the target leaving, and every template builds", function()
		local off = assert(bpf.command(template("off-CPU time"), { pid = 7 }))
		t.ok(off[#off]:find("sched_switch /pid == 7/ { @start[args.prev_pid]", 1, true))
		for _, tpl in ipairs(bpf.templates) do
			t.ok(bpf.command(tpl, { cmd = "x" }, { libc = "/usr/lib/libc.so.6" }), tpl.name)
		end
	end)

	t.it("malloc probes the binary's own libc, and refuses without one", function()
		local libc = bpf.libc_from_ldd({
			"\tlinux-vdso.so.1 (0x00007ffd0f5e2000)",
			"\tlibc.so.6 => /usr/lib/libc.so.6 (0x00007f8bb8c00000)",
			"\t/lib64/ld-linux-x86-64.so.2 => /usr/lib64/ld-linux-x86-64.so.2 (0x00007f8bb8e7c000)",
		})
		t.eq("/usr/lib/libc.so.6", libc)
		local argv = assert(bpf.command(template("malloc sizes"), { cmd = "hot" }, { libc = libc }))
		t.ok(argv[#argv]:find("uprobe:/usr/lib/libc.so.6:malloc /pid == cpid/", 1, true))
		t.eq(nil, bpf.libc_from_ldd({ "\tnot a dynamic executable" }))
		local none, err = bpf.command(template("malloc sizes"), { cmd = "hot" }, {})
		t.eq(nil, none)
		assert(err)
		t.ok(err:find("libc"))
	end)
end)

t.describe("sys semantic checkers", function()
	local semantic = require("features.sys.semantic")

	t.it("reads sparse warnings, errors and type-mismatch notes", function()
		-- Verbatim `sparse s.c` (sparse 0.6.5-rc1) on a file with each kind of finding.
		local items = semantic.parse_sparse({
			"s.c:2:5: warning: symbol 'global_fn' was not declared. Should it be static?",
			"s.c:5:18: warning: Using plain integer as NULL pointer",
			"s.c:9:25: error: return expression in void function",
			"t.c:2:27: warning: incorrect type in argument 1 (different base types)",
			"t.c:2:27:    expected int x",
			"t.c:2:27:    got char *s",
			"/src/abs.c:1:1: error: too many initializers",
		}, "/tree/drivers/gpu")
		t.eq(7, #items)
		t.eq({
			filename = "/tree/drivers/gpu/s.c",
			lnum = 2,
			col = 5,
			text = "symbol 'global_fn' was not declared. Should it be static?",
			type = "W",
		}, items[1])
		t.eq("E", items[3].type)
		t.eq(
			{ "I", "expected int x" },
			{ items[5].type, items[5].text },
			"a mismatch without its two types is unreadable"
		)
		t.eq("/src/abs.c", items[7].filename, "an absolute path was joined onto the tree")
	end)

	t.it("ignores sparse lines that carry no location", function()
		t.eq({}, semantic.parse_sparse({ "", "make: *** [scripts/Makefile.build:229] Error 1", "CHECK  s.c" }, "/tree"))
	end)

	t.it("reads coccinelle report mode, columns counted from one", function()
		-- Verbatim `spatch --very-quiet -D report --sp-file r.cocci k.c` (spatch 1.3.3).
		local items = semantic.parse_cocci({
			"Please check for false positives in the output before submitting a patch.",
			"k.c:4:11-17: use kmalloc instead of malloc",
			"k.c:5:11-17: use kmalloc instead of malloc",
			"drivers/x.c:88:3: ERROR: reference preceded by free",
		}, "/tree")
		t.eq(3, #items)
		t.eq({
			filename = "/tree/k.c",
			lnum = 4,
			col = 12,
			end_col = 18,
			text = "use kmalloc instead of malloc",
			type = "W",
		}, items[1])
		t.eq({ 88, 4, nil }, { items[3].lnum, items[3].col, items[3].end_col }, "a bare position has no end column")
	end)

	t.it("checks a kernel file through the tree's own build", function()
		local tree = vim.fn.tempname()
		vim.fn.mkdir(vim.fs.joinpath(tree, "mm"), "p")
		for _, marker in ipairs({ "MAINTAINERS", "Kbuild", "mm/slab.c" }) do
			vim.fn.writefile({ "" }, vim.fs.joinpath(tree, marker))
		end
		local buf = vim.fn.bufadd(vim.fs.joinpath(tree, "mm", "slab.c"))
		vim.fn.bufload(buf)
		local cmd, dir = semantic.sparse_cmd(buf)
		-- C=1 only checks what it recompiles, so an unchanged file reported nothing.
		t.eq({ "make", "C=2", "mm/slab.o" }, cmd)
		t.eq(tree, dir)
	end)
end)

t.describe("sys rr record and replay", function()
	local run = require("features.sys.run")

	t.it("inspects kernel.perf_event_paranoid setting", function()
		local ok, paranoid = run.check_rr_paranoid()
		t.eq("number", type(paranoid))
		t.eq(paranoid <= 1, ok)
	end)

	t.it("warns when rr is executed with paranoid > 1", function()
		t.reset()
		local warnings = {}
		local orig_warn = Snacks.notify.warn
		Snacks.notify.warn = function(msg, opts)
			table.insert(warnings, { msg = msg, opts = opts })
		end
		-- Run on buffer 0
		run.rr_record(0)
		Snacks.notify.warn = orig_warn
		if vim.fn.executable("rr") == 1 then
			local _, paranoid = run.check_rr_paranoid()
			if paranoid > 1 then
				t.ok(#warnings > 0, "expected warning when paranoid > 1")
				t.ok(warnings[1].msg:find("perf_event_paranoid"), "expected paranoid explanation in warning")
			end
		end
	end)
end)

t.describe("sys b4 patch workflow", function()
	local patch = require("features.sys.patch")

	t.it("parses b4 prep --show-info key-value output and commits", function()
		local lines = {
			"branch: b4/test-series",
			"cover-subject: EDITME: cover title for test-series",
			"base-commit: 828f29ca42b92a9b81d0a2df4794ef9669ec8a82",
			"start-commit: 2dd771c4ccd08a5e7452d99a47d943e16b1cf412",
			"end-commit: d5e9e91c2399af24a356b7516e5d63bb9b92352c",
			"series-range: 2dd771c4ccd08a5e7452d99a47d943e16b1cf412..d5e9e91c2399af24a356b7516e5d63bb9b92352c",
			"change-id: 20260912-test-series-cdb3a9c6ef09",
			"revision: 1",
			"needs-editing: False",
			"needs-recipients: True",
			"commit-d5e9e91: test commit",
			"commit-a1b2c3d: second commit",
		}

		local info = patch.parse_info(lines)
		t.ok(info ~= nil, "failed to parse info lines")
		assert(info)
		t.eq("b4/test-series", info.branch)
		t.eq("EDITME: cover title for test-series", info.cover_subject)
		t.eq("2dd771c4ccd08a5e7452d99a47d943e16b1cf412", info.start_commit)
		t.eq("20260912-test-series-cdb3a9c6ef09", info.change_id)
		t.eq(1, info.revision)
		t.eq(false, info.needs_editing)
		t.eq(true, info.needs_recipients)
		t.eq(2, #info.commits)
		t.eq("d5e9e91", info.commits[1].hash)
		t.eq("test commit", info.commits[1].subject)
	end)

	t.it("handles non-git buffers and empty check output gracefully", function()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		local file = dir .. "/untracked.txt"
		vim.fn.writefile({ "test" }, file)
		local buf = vim.fn.bufadd(file)
		vim.fn.bufload(buf)

		t.eq(nil, patch.git_root(buf))
		t.eq(nil, patch.parse_info({}))
		t.eq({}, patch.parse_check({}, dir))

		pcall(vim.api.nvim_buf_delete, buf, { force = true })
		pcall(vim.fn.delete, dir, "rf")
	end)

	t.it("parses b4 prep --check findings into quickfix items", function()
		local lines = {
			"Checking patches using:",
			"  /tree/scripts/checkpatch.pl -q --terse",
			"---",
			"● 914c33e35bf9: ext4: test commit for checkpatch",
			"  ● checkpatch.pl: :7643: WARNING: Missing commit description",
			"  ● checkpatch.pl: fs/ext4/super.c:12: ERROR: trailing whitespace",
			"---",
			"Success: 0, Warning: 1, Error: 1",
		}

		local items = patch.parse_check(lines, "/tree")
		t.eq(2, #items)
		t.eq({
			filename = "/tree",
			lnum = 7643,
			text = "[914c33e35b] Missing commit description",
			type = "W",
		}, items[1])
		t.eq({
			filename = "/tree/fs/ext4/super.c",
			lnum = 12,
			text = "[914c33e35b] trailing whitespace",
			type = "E",
		}, items[2])
	end)

	t.it("drives b4 prep, info, and dry-run send end-to-end", function()
		if vim.fn.executable("b4") == 0 or vim.fn.executable("git") == 0 then
			return
		end
		t.reset()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")

		-- Setup git repo with user and initial commit
		vim.system({ "git", "init", "-b", "main" }, { cwd = dir }):wait()
		vim.system({ "git", "config", "user.name", "Test User" }, { cwd = dir }):wait()
		vim.system({ "git", "config", "user.email", "test@example.com" }, { cwd = dir }):wait()
		vim.fn.writefile({ "hello" }, dir .. "/file.txt")
		vim.system({ "git", "add", "file.txt" }, { cwd = dir }):wait()
		vim.system({ "git", "commit", "-m", "initial commit" }, { cwd = dir }):wait()

		vim.cmd.edit(dir .. "/file.txt")
		local buf = vim.api.nvim_get_current_buf()

		t.eq(dir, patch.git_root(buf), "git_root did not find repo root")

		-- 1. Create prep branch
		patch.prep(buf, "my-series")

		-- 2. Add a commit to the series
		vim.fn.writefile({ "hello", "world" }, dir .. "/file.txt")
		vim.system({ "git", "commit", "-am", "my first patch" }, { cwd = dir }):wait()

		-- 3. Verify series info and json
		local info, err = patch.info(dir)
		t.ok(info ~= nil, "patch.info failed: " .. (err or ""))
		assert(info)
		t.eq("b4/my-series", info.branch)
		t.eq(1, #info.commits)
		t.eq("my first patch", info.commits[1].subject)

		local json_str = patch.json(dir)
		local decoded = vim.json.decode(json_str)
		t.eq("b4/my-series", decoded.branch)

		-- 4. Verify dry-run send
		patch.send_dry_run(buf)
		t.ok(output.showing(patch.send_title), "dry-run output pane was not displayed")
		output.close(patch.send_title)

		-- 5. Verify :SysPatch command dispatch
		vim.cmd("SysPatch dry-run")
		t.ok(output.showing(patch.send_title), "SysPatch dry-run command did not open pane")
		output.close(patch.send_title)

		pcall(vim.api.nvim_buf_delete, buf, { force = true })
		pcall(vim.fn.delete, dir, "rf")
	end)
end)
