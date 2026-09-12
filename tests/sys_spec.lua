--- Regression tests for the systems tools: every parser against real output captured
--- from the tool it reads, and the kernel helpers against a miniature tree.
local t = require("tests.harness")
local stack = require("features.sys.stack")
local elf = require("features.sys.elf")
local kernel = require("features.sys.kernel")

t.describe("sys stack", function()
	t.it("reads an ASan report with its sections", function()
		local items = stack.parse({
			"==385743==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x7b48 at pc 0x561d",
			"READ of size 4 at 0x7b48f11e0020 thread T0",
			"    #0 0x561ddf683fe2 in sum /src/s.c:10:79",
			"    #1 0x561ddf683e61 in main /src/s.c:16:9",
			"    #2 0x7f28f1e27c8d in __libc_start_call_main /usr/src/debug/glibc/csu/libc_start_call_main.h:59:16",
			"    #4 0x561ddf4e6104 in _start (/src/s+0x2d104) (BuildId: 11ef1af2)",
			"allocated by thread T0 here:",
			"    #1 0x561ddf683de4 in main /src/s.c:13:12",
		}, { root = "/src" })
		t.eq("ERROR: AddressSanitizer", items[1].text:match("ERROR: AddressSanitizer"))
		t.eq(
			{ "/src/s.c", 10, 79, "sum", true },
			{ items[2].filename, items[2].lnum, items[2].col, items[2].text, items[2].own }
		)
		t.eq(false, items[4].own, "libc is not the project")
		t.eq(0, items[5].valid, "`allocated by` should be a section header")
		t.eq(13, items[6].lnum)
		t.eq(6, #items, "a frame without a source location was kept")
	end)

	t.it("reads UBSan, gdb, valgrind, Rust, Go, Python, Node and Zig", function()
		local items = stack.parse({
			"s.c:15:28: runtime error: signed integer overflow: 2147483647 + 1",
			"#1  0x0000555555555189 in main (argc=1, argv=0x7fffffffe0a8) at s.c:16",
			"==12==    at 0x10916B: sum (s.c:10)",
			"thread 'main' panicked at src/main.rs:4:5:",
			"             at ./src/lib.rs:9:13",
			"\t/home/u/p/main.go:12 +0x1d",
			'  File "/p/app.py", line 3, in handler',
			"    at area (/p/x.js:3:5)",
			"/p/main.zig:7:5: 0x1034 in main (main)",
		}, {})
		local got = vim.tbl_map(function(i)
			return ("%s:%d"):format(i.filename, i.lnum)
		end, items)
		t.eq({
			"s.c:15",
			"s.c:16",
			"s.c:10",
			"src/main.rs:4",
			"src/lib.rs:9",
			"/home/u/p/main.go:12",
			"/p/app.py:3",
			"/p/x.js:3",
			"/p/main.zig:7",
		}, got)
		t.eq("handler", items[7].text)
	end)

	t.it("quickfix starts at the first frame in the project", function()
		local items = stack.parse({
			"    #0 0x1 in memcpy /usr/include/string.h:1:1",
			"    #1 0x2 in copy /src/a.c:4:2",
		}, { root = "/src" })
		stack.to_quickfix(items, "test")
		t.eq(2, vim.fn.getqflist({ idx = 0 }).idx)
	end)
end)

t.describe("sys elf", function()
	t.it("parses nm and matches names across languages", function()
		local syms = elf.parse_nm({
			"00000000001caef8 0000000000000063 t sum",
			"0000000000001000 0000000000000010 T main.(*Box).Scale",
		})
		t.eq({ addr = 0x1caef8, size = 0x63, kind = "t", name = "sum" }, syms[1])
		t.ok(elf.names("main.(*Box).Scale", "Scale"))
		t.ok(elf.names("playground::compute::h0123456789abcdef", "compute"))
		t.ok(elf.names("demo.area", "area"))
		t.ok(not elf.names("summary", "sum"), "a prefix is not a match")
	end)

	t.it("picks the obvious symbol instead of asking", function()
		-- Zig exports one function under two names; Rust's std has its own `report`.
		local zig = elf.best_matches({
			{ addr = 0x10, size = 9, kind = "t", name = "area" },
			{ addr = 0x10, size = 9, kind = "t", name = "main.area" },
		}, "area")
		t.eq(1, #zig, "aliases at one address were offered twice")
		local rust = elf.best_matches({
			{ addr = 0x20, size = 9, kind = "t", name = "playground::report" },
			{ addr = 0x30, size = 3, kind = "t", name = "<() as std::process::Termination>::report" },
		}, "report")
		t.eq(
			{ "playground::report" },
			vim.tbl_map(function(s)
				return s.name
			end, rust)
		)
	end)

	t.it("maps objdump -l instructions to source lines", function()
		local lines, map = elf.parse_objdump({
			"objdump: DWARF error: mangled line number section (bad file number)",
			"",
			"s:     file format elf64-x86-64",
			"Disassembly of section .text:",
			"00000000001caef8 <sum>:",
			"sum():",
			"/src/s.c:10",
			"  1caef8:\tpush   rbp",
			"/src/s.c:11 (discriminator 1)",
			"  1caef9:\tmov    rbp,rsp",
		}, "/src/s.c")
		t.eq({ "00000000001caef8 <sum>:", "  1caef8:\tpush   rbp", "  1caef9:\tmov    rbp,rsp" }, lines)
		t.eq({ [2] = 10, [3] = 11 }, map)
	end)
end)

t.describe("sys kernel", function()
	--- A tree with just enough shape to be recognised.
	---@return string
	local function mini_tree()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir .. "/drivers/net", "p")
		vim.fn.writefile({}, dir .. "/MAINTAINERS")
		vim.fn.writefile({}, dir .. "/Kbuild")
		vim.fn.writefile({ "config NET_DEMO", '\ttristate "demo"' }, dir .. "/drivers/net/Kconfig")
		vim.fn.writefile({ "#ifdef CONFIG_NET_DEMO", "#endif" }, dir .. "/drivers/net/demo.c")
		return dir
	end

	t.it("recognises a tree and parses checkpatch --terse", function()
		local dir = mini_tree()
		t.reset()
		vim.cmd.edit(dir .. "/drivers/net/demo.c")
		t.ok(kernel.tree(0), "the tree was not recognised")
		local items = kernel.parse_checkpatch({
			"drivers/net/demo.c:1: WARNING:CONFIG_DESCRIPTION: please write a help paragraph",
			"drivers/net/demo.c:2: ERROR: trailing whitespace",
			"total: 1 errors, 1 warnings, 2 lines checked",
		}, dir)
		t.eq(2, #items)
		t.eq("E", items[2].type)
		t.eq(dir .. "/drivers/net/demo.c", items[1].filename)
	end)

	t.it("jumps from CONFIG_ to its Kconfig entry", function()
		if vim.fn.executable("rg") == 0 then
			return
		end
		local dir = mini_tree()
		t.reset()
		vim.cmd.edit(dir .. "/drivers/net/demo.c")
		vim.api.nvim_win_set_cursor(0, { 1, 10 })
		t.eq("NET_DEMO", kernel.symbol_at_cursor())
		kernel.kconfig(0)
		t.eq("Kconfig", vim.fs.basename(vim.api.nvim_buf_get_name(0)))
		t.eq(1, vim.api.nvim_win_get_cursor(0)[1])
	end)

	t.it("boots halted with gdbstub and no KASLR", function()
		local dir = mini_tree()
		t.eq(nil, (kernel.qemu_cmd(dir)), "no bzImage should mean no command")
		vim.fn.mkdir(dir .. "/arch/x86/boot", "p")
		vim.fn.writefile({}, dir .. "/arch/x86/boot/bzImage")
		local cmd = assert(kernel.qemu_cmd(dir))
		local text = table.concat(cmd, " ")
		t.ok(text:find("-s -S", 1, true), "not halted for gdb")
		t.ok(text:find("nokaslr", 1, true), "KASLR left on; breakpoints would miss")
	end)

	t.it("detects vmlinuz or explicit image for QEMU command", function()
		local dir = mini_tree()
		vim.fn.writefile({}, dir .. "/vmlinuz")
		local cmd = assert(kernel.qemu_cmd(dir))
		t.ok(cmd[3]:find("vmlinuz"), "failed to find root vmlinuz: " .. vim.inspect(cmd))

		local custom_img = dir .. "/my_kernel.bin"
		vim.fn.writefile({}, custom_img)
		local custom_cmd = assert(kernel.qemu_cmd(dir, { image = custom_img }))
		t.eq(custom_img, custom_cmd[3])
	end)

	t.it("runs kernel helpers against a real kernel tree when present", function()
		local real_tree = "/home/quantum/Projects/linux"
		if not vim.uv.fs_stat(vim.fs.joinpath(real_tree, "MAINTAINERS")) or vim.fn.executable("rg") == 0 then
			return
		end
		t.reset()
		local ext4_file = vim.fs.joinpath(real_tree, "fs/ext4/super.c")
		vim.cmd.edit(ext4_file)
		local buf = vim.api.nvim_get_current_buf()

		t.eq(real_tree, kernel.tree(buf), "failed to detect real kernel tree root")

		-- Test get_maintainer.pl on ext4
		local res_m = vim.system(
			{ "perl", vim.fs.joinpath(real_tree, "scripts/get_maintainer.pl"), "-f", ext4_file },
			{ cwd = real_tree }
		):wait(30000)
		t.eq(0, res_m.code, "get_maintainer.pl exited non-zero")
		t.ok(res_m.stdout and res_m.stdout:find("Theodore Ts'o", 1, true) ~= nil, "ext4 maintainer missing")

		-- Test checkpatch.pl on ext4
		local res_c = vim.system({
			"perl",
			vim.fs.joinpath(real_tree, "scripts/checkpatch.pl"),
			"--terse",
			"--no-tree",
			"--show-types",
			"--file",
			ext4_file,
		}, { cwd = real_tree }):wait(30000)
		local items = kernel.parse_checkpatch(vim.split(res_c.stdout or "", "\n", { plain = true }), real_tree)
		t.ok(#items > 0, "no checkpatch items parsed on ext4/super.c")
		t.eq("W", items[1].type)
		t.eq(ext4_file, items[1].filename)

		-- Test Kconfig jump on CONFIG_EXT4_FS_POSIX_ACL
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local found_line = nil
		for i, line in ipairs(lines) do
			local s = line:find("CONFIG_EXT4_FS_POSIX_ACL", 1, true)
			if s then
				found_line = i
				vim.api.nvim_win_set_cursor(0, { i, s + 7 })
				break
			end
		end
		t.ok(found_line ~= nil, "symbol not found in super.c")
		t.eq("EXT4_FS_POSIX_ACL", kernel.symbol_at_cursor())
		kernel.kconfig(buf)
		t.eq("Kconfig", vim.fs.basename(vim.api.nvim_buf_get_name(0)))
		local jumped_line = vim.api.nvim_get_current_line()
		t.ok(jumped_line:find("EXT4_FS_POSIX_ACL", 1, true) ~= nil, "did not jump to EXT4_FS_POSIX_ACL definition")

		-- Test e1000 Kconfig jump on CONFIG_NET_POLL_CONTROLLER
		local e1000_file = vim.fs.joinpath(real_tree, "drivers/net/ethernet/intel/e1000/e1000_main.c")
		vim.cmd.edit(e1000_file)
		local e1000_buf = vim.api.nvim_get_current_buf()
		local e_lines = vim.api.nvim_buf_get_lines(e1000_buf, 0, -1, false)
		for i, line in ipairs(e_lines) do
			local s = line:find("CONFIG_NET_POLL_CONTROLLER", 1, true)
			if s then
				vim.api.nvim_win_set_cursor(0, { i, s + 7 })
				break
			end
		end
		t.eq("NET_POLL_CONTROLLER", kernel.symbol_at_cursor())
		kernel.kconfig(e1000_buf)
		t.eq("Kconfig", vim.fs.basename(vim.api.nvim_buf_get_name(0)))
		t.ok(vim.api.nvim_get_current_line():find("NET_POLL_CONTROLLER", 1, true) ~= nil)
	end)
end)

t.describe("sys perf and strace", function()
	t.it("parses perf's per-line report and marks the source", function()
		local profile = require("features.sys.profile")
		local path = t.file("hot.c", { "int main(void)", "{", "  work();", "}" })
		local hot = profile.parse({
			"    76.45%  " .. path .. ":3",
			"    23.43%  " .. path .. ":1",
			"     0.60%  ??:0",
		})
		t.eq(2, #hot, "the unknown location was kept")
		t.eq({ 76.45, 3 }, { hot[1].pct, hot[1].lnum })

		t.reset()
		vim.cmd.edit(path)
		profile.apply(hot)
		local ns = vim.api.nvim_create_namespace("sys_profile")
		t.eq(2, #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}), "hot lines were not marked")
		t.ok(profile.active())
		profile.clear()
		t.eq(0, #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}), "clear left marks behind")
	end)

	t.it("parses strace -k and finds the program's own frame", function()
		local trace = require("features.sys.trace")
		local calls = trace.parse({
			'2062449 15:28:10.337713 openat(AT_FDCWD, "/nonexistent/file", O_RDONLY) = -1 ENOENT (No such file or directory) <0.000011>',
			" > /usr/lib/libc.so.6(__open64+0x127) [0x13c317]",
			" > /src/io(main+0x2c) [0x11bc]",
			" > /usr/lib/libc.so.6() [0x27c8e]",
			'2062449 15:28:10.337763 write(1, "hi\\n", 3) = 3 <0.000007>',
			"2062449 15:28:10.337842 +++ exited with 1 +++",
		})
		t.eq(3, #calls)
		t.eq({ "openat", "ENOENT" }, { calls[1].syscall, calls[1].error })
		t.eq(nil, calls[2].error)
		t.eq("11bc", trace.own_frame(calls[1], "/src/io").addr, "libc's frame was taken for the program's")
		t.eq(nil, trace.own_frame(calls[1], "/src/other"))
	end)
end)

t.describe("sys hex", function()
	--- Opens `bytes` as a file, toggles hex twice, writes, and returns what is on disk.
	---@param name string
	---@param bytes string
	---@return string
	local function roundtrip(name, bytes)
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		local path = dir .. "/" .. name
		local f = assert(io.open(path, "wb"))
		f:write(bytes)
		f:close()
		t.reset()
		vim.cmd.edit(path)
		local buf = vim.api.nvim_get_current_buf()
		local sys = require("features.sys")
		sys.hex(buf)
		t.eq("xxd", vim.bo[buf].filetype)
		sys.hex(buf)
		vim.cmd("silent write")
		local back = assert(io.open(path, "rb"))
		local content = back:read("*a")
		back:close()
		vim.cmd("bwipe!")
		return content
	end

	t.it("round-trips a binary with NULs and newline bytes unchanged", function()
		if vim.fn.executable("xxd") == 0 then
			return
		end
		local bytes = "\127ELF\2\1\1\0\0\0\n\n\0\255\r\n\0tail"
		t.eq(bytes, roundtrip("blob.bin", bytes), "the binary changed")
	end)

	t.it("keeps CRLF and a missing final newline", function()
		if vim.fn.executable("xxd") == 0 then
			return
		end
		t.eq("a\r\nb", roundtrip("crlf.txt", "a\r\nb"), "line endings or the final newline changed")
	end)
end)

t.describe("sys binary choice", function()
	t.it("prefers the binary named after the current file over the remembered one", function()
		-- Profiling `hot` then pressing strace in syscalls.c used to trace `hot` again.
		if vim.fn.executable("cc") == 0 then
			return
		end
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		vim.fn.mkdir(dir .. "/.git", "p")
		for _, name in ipairs({ "hot", "syscalls" }) do
			vim.fn.writefile({ "int main(void) { return 0; }" }, dir .. "/" .. name .. ".c")
			vim.system({ "cc", "-o", dir .. "/" .. name, dir .. "/" .. name .. ".c" }):wait()
		end
		t.reset()
		vim.cmd.edit(dir .. "/syscalls.c")
		local picked
		require("features.sys.util").binary(0, function(path)
			picked = path
		end)
		t.eq("syscalls", picked and vim.fs.basename(picked))
	end)
end)

t.describe("sys config", function()
	t.it("C and C++ debug configs do not ask rust-analyzer", function()
		local ok, dap = pcall(require, "dap")
		if not ok or not dap.configurations.c then
			return
		end
		for _, config in ipairs(dap.configurations.c) do
			t.ok(config.type ~= "codelldb" or config.program ~= (dap.configurations.rust or {})[1].program)
		end
		t.ok(dap.adapters.gdb, "gdb DAP adapter missing")
	end)

	t.it("the registry installs the systems tools", function()
		local names = vim.tbl_map(function(tool)
			return tool.name
		end, require("toolchain.registry").eco.sys.tool)
		for _, want in ipairs({ "pahole", "perf", "strace", "valgrind", "bpftrace", "qemu" }) do
			t.ok(vim.tbl_contains(names, want), want .. " missing from the registry")
		end
	end)
end)
