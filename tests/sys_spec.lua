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
		t.eq({ "/src/s.c", 10, 79, "sum", true }, { items[2].filename, items[2].lnum, items[2].col, items[2].text, items[2].own })
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
		local syms = elf.parse_nm({ "00000000001caef8 0000000000000063 t sum", "0000000000001000 0000000000000010 T main.(*Box).Scale" })
		t.eq({ addr = 0x1caef8, size = 0x63, kind = "t", name = "sum" }, syms[1])
		t.ok(elf.names("main.(*Box).Scale", "Scale"))
		t.ok(elf.names("playground::compute::h0123456789abcdef", "compute"))
		t.ok(elf.names("demo.area", "area"))
		t.ok(not elf.names("summary", "sum"), "a prefix is not a match")
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
