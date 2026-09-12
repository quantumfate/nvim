--- Regression tests from the third bug hunt: refactor edge shapes, language actions on
--- real project layouts, and the scaffold. Everything here runs without a language
--- server; shapes that need one were verified against real servers when fixed.
local t = require("tests.harness")
local Plan = require("features.refactor.plan")
local signature = require("features.refactor.ops.signature")

---@param lang string
---@return boolean
local function has_parser(lang)
	return (pcall(vim.treesitter.language.inspect, lang))
end

--- Runs `fn` with warnings captured.
---@param fn fun()
---@return string[]
local function warnings(fn)
	local seen, real = {}, Snacks.notify.warn
	Snacks.notify.warn = function(msg)
		table.insert(seen, msg)
	end
	pcall(fn)
	Snacks.notify.warn = real
	return seen
end

--- The plan an op would apply, captured instead of applied.
---@param fn fun()
---@return refactor.Plan?
local function planned(fn)
	local real, got = Plan.finish, nil
	Plan.finish = function(plan)
		Plan.done()
		got = plan
	end
	local notify = Snacks.notify.warn
	Snacks.notify.warn = function() end
	pcall(fn)
	vim.wait(3000, function()
		return got ~= nil
	end, 20)
	Plan.finish, Snacks.notify.warn = real, notify
	return got
end

---@param plan refactor.Plan
---@return string
local function conflicts(plan)
	return table.concat(
		vim.tbl_map(function(c)
			return c.text
		end, plan.conflicts),
		"\n"
	)
end

t.describe("edges refactor", function()
	t.it("refuses a K&R definition", function()
		if not has_parser("c") then
			return
		end
		t.reset()
		t.buffer({ "int kr(a, b)", "int a;", "int b;", "{ return a + b; }" }, "c")
		vim.api.nvim_win_set_cursor(0, { 1, 7 })
		local seen = warnings(function()
			signature.add_param({ spec = "c:int", preview = false })
		end)
		t.ok(seen[1] and seen[1]:find("K&R"), vim.inspect(seen))
	end)

	t.it("refuses a function-pointer variable", function()
		if not has_parser("c") then
			return
		end
		t.reset()
		t.buffer({ "int (*fp)(int, int) = 0;" }, "c")
		vim.api.nvim_win_set_cursor(0, { 1, 12 })
		local seen = warnings(function()
			signature.add_param({ spec = "c:int", preview = false })
		end)
		t.ok(seen[1] and seen[1]:find("function pointer"), vim.inspect(seen))
	end)

	t.it("does not edit the function around a Rust closure", function()
		if not has_parser("rust") then
			return
		end
		t.reset()
		local buf = t.buffer({ "fn main() {", "    let f = |x: i32, y: i32| x + y;", "}" }, "rust")
		vim.api.nvim_win_set_cursor(0, { 2, 14 })
		warnings(function()
			signature.add_param({ spec = "z:i32", preview = false })
		end)
		t.eq("fn main() {", vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
	end)

	t.it("removing the last keyword-only parameter also removes the bare *", function()
		if not has_parser("python") then
			return
		end
		t.reset()
		t.buffer({ "def kwonly(a, *, b):", "    return a" }, "python")
		vim.api.nvim_win_set_cursor(0, { 1, 17 })
		local plan = planned(function()
			signature.remove_param({ preview = false })
		end)
		t.ok(plan, "no plan")
		assert(plan and plan.edits)
		local _, edits = next(plan.edits)
		assert(edits and edits[1])
		local e = edits[1]
		-- `, *, b` spans columns 12 up to the `)` at 18.
		t.eq(
			{ 0, 12, 0, 18 },
			{ e.range.start.line, e.range.start.character, e.range["end"].line, e.range["end"].character }
		)
	end)

	t.it("a separator is not a parameter to swap with", function()
		if not has_parser("python") then
			return
		end
		t.reset()
		t.buffer({ "def posonly(a, b, /, c):", "    return a" }, "python")
		vim.api.nvim_win_set_cursor(0, { 1, 15 })
		local seen = warnings(function()
			signature.reorder_param({ direction = "next", preview = false })
		end)
		t.ok(seen[1] and seen[1]:find("neighbouring"), vim.inspect(seen))
	end)

	t.it("removing a destructured TS parameter is a conflict", function()
		if not has_parser("typescript") then
			return
		end
		t.reset()
		t.buffer(
			{ "function f({ a, b }: { a: number; b: number }, c: number) {", "  return a + b;", "}" },
			"typescript"
		)
		vim.api.nvim_win_set_cursor(0, { 1, 12 })
		local plan = planned(function()
			signature.remove_param({ preview = false })
		end)
		t.ok(plan and conflicts(plan):find("destructured"), plan and conflicts(plan) or "no plan")
	end)

	t.it("a default argument in a C header is a conflict", function()
		if not has_parser("cpp") then
			return
		end
		t.reset()
		local path = t.file("lib.h", { "int add(int a, int b);" })
		vim.cmd.edit(path)
		vim.bo.filetype = "cpp"
		vim.api.nvim_win_set_cursor(0, { 1, 4 })
		local plan = planned(function()
			signature.add_param({ spec = "depth:int=0", preview = false })
		end)
		t.ok(plan and conflicts(plan):find("default arguments"), plan and conflicts(plan) or "no plan")
	end)
end)

t.describe("edges root", function()
	t.it("a root cached for an empty buffer does not stick to the file opened into it", function()
		local root = require("lib.root")
		local a, b = vim.fn.tempname(), vim.fn.tempname()
		for _, dir in ipairs({ a, b }) do
			vim.fn.mkdir(dir .. "/.git", "p")
			vim.fn.writefile({ "x" }, dir .. "/f.txt")
		end
		t.reset()
		vim.cmd.edit(a .. "/f.txt")
		t.eq(vim.uv.fs_realpath(a), root.get({ buf = 0 }))
		vim.cmd("enew")
		local empty = vim.api.nvim_get_current_buf()
		root.get({ buf = empty })
		-- `:edit` from an unmodified empty buffer reuses its number.
		vim.cmd.edit(b .. "/f.txt")
		t.eq(empty, vim.api.nvim_get_current_buf(), "precondition: the empty buffer was reused")
		t.eq(vim.uv.fs_realpath(b), root.get({ buf = 0 }), "the stale root stuck")
	end)
end)

t.describe("edges lang", function()
	t.it("splits compile commands like a shell", function()
		local c = require("features.lang.c")
		t.eq(
			{ "cc", '-DGREETING="hello world"', "-Iinclude dir", "-c", "a.c" },
			c.shell_split([[cc "-DGREETING=\"hello world\"" '-Iinclude dir' -c a.c]])
		)
	end)

	t.it("finds compile_commands.json in build/", function()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir .. "/build", "p")
		vim.fn.mkdir(dir .. "/src", "p")
		vim.fn.writefile({ "project(x C)" }, dir .. "/CMakeLists.txt")
		vim.fn.writefile({ "[]" }, dir .. "/build/compile_commands.json")
		vim.fn.writefile({ "int main(void) { return 0; }" }, dir .. "/src/main.c")
		t.reset()
		vim.cmd.edit(dir .. "/src/main.c")
		t.eq(dir .. "/build/compile_commands.json", require("features.lang.c").database(0))
	end)

	t.it("caches parsed compile_commands.json and strips dependency flags", function()
		local c = require("features.lang.c")
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir .. "/drivers/net", "p")
		local driver = dir .. "/drivers/net/e1000.c"
		vim.fn.writefile({ "int x = 1;" }, driver)
		local db_content = vim.json.encode({
			{
				directory = dir,
				file = "drivers/net/e1000.c",
				arguments = {
					"gcc",
					"-Wp,-MMD,drivers/net/.e1000.o.d",
					"-nostdinc",
					"-I./include",
					"-D__KERNEL__",
					"-c",
					"-o",
					"drivers/net/e1000.o",
					"drivers/net/e1000.c",
				},
			},
		})
		vim.fn.writefile({ db_content }, dir .. "/compile_commands.json")
		t.reset()
		vim.cmd.edit(driver)
		local buf = vim.api.nvim_get_current_buf()

		local cmd, workdir, from_db = c.invocation(buf, { "-S", "-masm=intel" })
		t.eq(true, from_db, "flags were not extracted from compile_commands.json")
		t.eq(dir, workdir)
		t.ok(vim.tbl_contains(cmd, "-D__KERNEL__"), "kernel define missing from command")
		t.ok(vim.tbl_contains(cmd, "-I./include"), "kernel include missing from command")
		t.ok(not vim.tbl_contains(cmd, "-o"), "-o was not stripped")
		t.ok(not vim.tbl_contains(cmd, "drivers/net/e1000.o"), "object target was not stripped")
		for _, arg in ipairs(cmd) do
			t.ok(not arg:match("^%-Wp,%-MMD"), "-Wp,-MMD was not stripped: " .. arg)
		end

		-- Verify cache was populated
		local cached = c.db_cache[dir .. "/compile_commands.json"]
		t.ok(cached ~= nil, "compile_commands cache was not populated")

		pcall(vim.api.nvim_buf_delete, buf, { force = true })
		pcall(vim.fn.delete, dir, "rf")
	end)

	t.it("switches between C source and header without language server", function()
		local c = require("features.lang.c")
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		local src = dir .. "/test_shape.c"
		local hdr = dir .. "/test_shape.h"
		vim.fn.writefile({ '#include "test_shape.h"', "int foo(void) { return 1; }" }, src)
		vim.fn.writefile({ "int foo(void);" }, hdr)
		t.reset()
		vim.cmd.edit(src)
		local buf = vim.api.nvim_get_current_buf()

		c.related(buf)
		t.eq(hdr, vim.api.nvim_buf_get_name(0), "did not switch to header")

		c.related(vim.api.nvim_get_current_buf())
		t.eq(src, vim.api.nvim_buf_get_name(0), "did not switch back to source")

		pcall(vim.api.nvim_buf_delete, 0, { force = true })
		pcall(vim.fn.delete, dir, "rf")
	end)

	t.it("links assembly rows only to the open file's lines", function()
		local output = require("features.lang.output")
		local _, map = output.strip_asm({
			'\t.file\t1 "/src" "main.c"',
			'\t.file\t2 "/usr/include" "stdio.h"',
			"\t.loc\t1 10 0",
			"\tpush\trbp",
			"\t.loc\t2 300 0",
			"\tmov\teax, 1",
		}, "/src/main.c")
		t.eq(10, map[1])
		t.eq(nil, map[2], "a header's line number moved the cursor in main.c")
	end)

	t.it("keeps only this file's functions from a crate's assembly", function()
		local lines, map = require("features.lang.output").strip_asm({
			'\t.file\t1 "/src" "main.rs"',
			'\t.file\t2 "/rustc/library/core/src" "ptr.rs"',
			"_ZN4core3ptr13drop_in_place17h0E:",
			"\t.loc\t2 500 0",
			"\tret",
			"_ZN2tr4main17h1E:",
			"\t.loc\t1 7 0",
			"\tpush\trbp",
			"\tret",
		}, "/src/main.rs", { only_source_functions = true })
		t.eq({ "_ZN2tr4main17h1E:", "\tpush\trbp", "\tret" }, lines)
		t.eq(7, map[2])
	end)

	t.it("splits a macro call's arguments on top-level commas", function()
		if not has_parser("rust") then
			return
		end
		t.reset()
		local buf = t.buffer({ 'fn main() { println!("{}", plain(f(1, 2), 3)); }' }, "rust")
		local root = vim.treesitter.get_parser(buf, "rust"):parse()[1]:root()
		local node = root:named_descendant_for_range(0, 27, 0, 27) -- `plain`
		assert(node)
		t.eq("plain", vim.treesitter.get_node_text(node, buf))
		local sibling = node:next_sibling()
		assert(sibling)
		local args = signature.macro_args(sibling)
		t.eq(2, #args, "the nested call's comma split the outer arguments")
		local sr, sc = args[1].first:start()
		local er, ec = args[1].last:end_()
		t.eq("f(1, 2)", vim.api.nvim_buf_get_text(buf, sr, sc, er, ec, {})[1])
	end)

	t.it("picks the cargo target from the file's path", function()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir .. "/src/bin", "p")
		vim.fn.writefile({ "[package]", 'name = "both"' }, dir .. "/Cargo.toml")
		vim.fn.writefile({}, dir .. "/src/lib.rs")
		vim.fn.writefile({}, dir .. "/src/main.rs")
		vim.fn.writefile({}, dir .. "/src/util.rs")
		vim.fn.writefile({}, dir .. "/src/bin/tool.rs")
		local rust = require("features.lang.rust")
		local function target(rel)
			t.reset()
			vim.cmd.edit(dir .. "/" .. rel)
			return rust.target_args(0)
		end
		t.eq({ "--bin", "both" }, target("src/main.rs"))
		t.eq({ "--lib" }, target("src/util.rs"))
		t.eq({ "--bin", "tool" }, target("src/bin/tool.rs"))
	end)

	t.it("names the build.zig modules a file imports", function()
		t.reset()
		t.buffer(
			{ 'const std = @import("std");', 'const lib = @import("mylib");', 'const u = @import("util.zig");' },
			"zig"
		)
		t.eq({ "mylib" }, require("features.lang.zig").module_imports(0))
	end)

	t.it("reads cgo positions in Go assembly", function()
		local lines = require("features.lang.go").asm_lines("/src/cg.go")({
			"main.f STEXT size=4",
			"\t0x0000 00000 (/src/cg.go:6[cg.cgo1.go:9])\tTEXT\tmain.f(SB), ABIInternal, $0-0",
			"\t0x0000 00000 (/src/cg.go:7[cg.cgo1.go:10])\tRET",
		})
		t.ok(#lines == 3, "cgo lines were dropped: " .. vim.inspect(lines))
	end)

	t.it("does not offer shared libraries or objects as runnable", function()
		if vim.fn.executable("cc") == 0 then
			return
		end
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		vim.fn.writefile({ "int f(void) { return 1; }" }, dir .. "/f.c")
		vim.system({ "cc", "-shared", "-fPIC", "-o", dir .. "/libf.so.1.2.3", dir .. "/f.c" }):wait()
		vim.system({ "cc", "-c", "-o", dir .. "/f.obj", dir .. "/f.c" }):wait()
		vim.fn.setfperm(dir .. "/f.obj", "rwxr-xr-x")
		local found = require("features.lang.binary").candidates(dir)
		t.eq({}, found, "offered: " .. vim.inspect(found))
	end)

	t.it("a program that cannot start does not leave a job running", function()
		local output = require("features.lang.output")
		local jobs = require("features.lang.jobs")
		local real = Snacks.notify.error
		Snacks.notify.error = function() end
		output.run({ cmd = { "no-such-compiler-xyz" }, title = "ghost probe" })
		Snacks.notify.error = real
		t.eq(false, jobs.running("ghost probe") and true or false, "the spinner never stops")
	end)

	t.it("the scaffolded C build picks the build system", function()
		local tools = require("scaffold.tools")
		local build = table.concat(tools.eco.c.build, "\n")
		t.ok(build:find("CMakeLists.txt", 1, true) and build:find("meson", 1, true), build)
	end)
end)
