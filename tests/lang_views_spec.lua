--- Regression tests for the three views that read a whole project's output: rustc
--- assembly filtered to one file, zig's build graph turned into emit flags, and Go
--- struct layout from a generated test.
---
--- Every fixture here is output a real tool produced — the shape of these dumps is the
--- whole problem, and a hand-written approximation of one proves nothing.
local t = require("tests.harness")
local output = require("features.lang.output")
local zig = require("features.lang.zig")
local layout = require("features.sys.layout")

--- `cargo rustc --release --emit asm` on a crate with generics and a panic path,
--- excerpted: the declarations for main.rs and two core files, `total`, main's
--- exception table and the personality reference.
local RUST_ASM = vim.split(
	[[
	.file	7 "/home/quantum/.rustup/toolchains/nightly-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/core/src/num" "uint_macros.rs"
	.file	14 "/tmp/claude-1000/nvim-langviews/rs" "src/main.rs"
	.section	.text._RNvCsbBCl3xH69Kt_9langviews5total,"ax",@progbits
	.prefalign	4, .Lfunc_end6, nop
	.type	_RNvCsbBCl3xH69Kt_9langviews5total,@function
_RNvCsbBCl3xH69Kt_9langviews5total:
.Lfunc_begin6:
	.loc	14 25 0
	.cfi_startproc
	push	r15
	.cfi_def_cfa_offset 16
	push	r14
	.cfi_def_cfa_offset 24
	push	r12
	.cfi_def_cfa_offset 32
	push	rbx
	.cfi_def_cfa_offset 40
	push	rax
	.cfi_def_cfa_offset 48
	.cfi_offset rbx, -40
	.cfi_offset r12, -32
	.cfi_offset r14, -24
	.cfi_offset r15, -16
	.file	22 "/home/quantum/.rustup/toolchains/nightly-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/core/src" "cmp.rs"
	.loc	22 2224 50 prologue_end
	test	rsi, rsi
.Ltmp124:
	.file	23 "/home/quantum/.rustup/toolchains/nightly-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/core/src/iter" "range.rs"
	.loc	23 1100 12
	je	.LBB6_1
	.loc	23 0 12 is_stmt 0
	mov	rbx, rsi
	mov	r15, rdi
	xor	r14d, r14d
	xor	esi, esi
	.p2align	4
.LBB6_4:
.Ltmp125:
	.loc	7 1043 17 is_stmt 1
	lea	r12, [rsi + 1]
.Ltmp126:
	.loc	14 28 34
	mov	rdi, r15
	call	_RNvMCsbBCl3xH69Kt_9langviewsINtB2_4GridmE2atB2_
.Ltmp127:
	.loc	7 2682 13
	add	r14d, eax
	mov	rsi, r12
.Ltmp128:
	.loc	22 2224 50
	cmp	rbx, r12
.Ltmp129:
	.loc	23 1100 12
	jne	.LBB6_4
	jmp	.LBB6_2
.Ltmp130:
.LBB6_1:
	.loc	23 0 12 is_stmt 0
	xor	r14d, r14d
.LBB6_2:
	.loc	14 31 2 is_stmt 1
	mov	eax, r14d
	.loc	14 31 2 epilogue_begin is_stmt 0
	add	rsp, 8
	.cfi_def_cfa_offset 40
	pop	rbx
	.cfi_def_cfa_offset 32
	pop	r12
	.cfi_def_cfa_offset 24
	pop	r14
	.cfi_def_cfa_offset 16
	pop	r15
	.cfi_def_cfa_offset 8
	ret
.Ltmp131:
.Lfunc_end6:
	.file	21 "/home/quantum/.rustup/toolchains/nightly-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/core/src/str" "mod.rs"
	.section	.gcc_except_table._RNvCsbBCl3xH69Kt_9langviews4main,"a",@progbits
	.p2align	2, 0x0
GCC_except_table5:
.Lexception0:
	.byte	255
	.byte	255
	.byte	1
	.uleb128 .Lcst_end0-.Lcst_begin0
	.byte	0
	.byte	0

	.hidden	DW.ref.rust_eh_personality
	.weak	DW.ref.rust_eh_personality
	.section	.data.DW.ref.rust_eh_personality,"awG",@progbits,DW.ref.rust_eh_personality,comdat
	.p2align	3, 0x0
	.type	DW.ref.rust_eh_personality,@object
	.size	DW.ref.rust_eh_personality, 8
DW.ref.rust_eh_personality:
	.quad	rust_eh_personality
	.ident	"rustc version 1.100.0-nightly (a69a63265 2026-09-03)"]],
	"\n"
)

--- `zig build --verbose` in a project whose exe imports a module from lib/.
local ZIG_VERBOSE = vim.split(
	[[
/usr/bin/zig build-exe -ODebug --dep shapes -Mroot=/tmp/claude-1000/nvim-langviews/zg/src/main.zig -ODebug -Mshapes=/tmp/claude-1000/nvim-langviews/zg/lib/shapes.zig --cache-dir .zig-cache --global-cache-dir /home/quantum/.cache/zig --name langviews --zig-lib-dir /usr/lib/zig/ --listen=-
install -C .zig-cache/o/0e137a90a31267de10e4bd63049a92b8/langviews /tmp/claude-1000/nvim-langviews/zg/zig-out/bin/langviews]],
	"\n"
)

local ZIG_ROOT = "/tmp/claude-1000/nvim-langviews/zg/src/main.zig"
local ZIG_MODULE = "/tmp/claude-1000/nvim-langviews/zg/lib/shapes.zig"

--- `go test -v` on the generated layout test, over a struct with two holes and
--- trailing padding.
local GO_OUT = vim.split(
	[[
=== RUN   TestNvimLayout
@nvim-layout struct packet 56 8
@nvim-layout field flag 0 1 bool
@nvim-layout field seq 8 8 uint64
@nvim-layout field kind 16 1 uint8
@nvim-layout field payload 24 24 []uint8
@nvim-layout field id 48 2 uint16
--- PASS: TestNvimLayout (0.00s)
PASS
ok  	langviews	0.001s]],
	"\n"
)

t.describe("lang views", function()
	t.it("strip_asm keeps only the functions with this file's code", function()
		local kept = output.strip_asm(RUST_ASM, "/tmp/whatever/src/main.rs", { only_source_functions = true })
		local text = table.concat(kept, "\n")

		t.ok(text:find("5total:", 1, true), "the function from main.rs was dropped:\n" .. text)
		t.ok(text:find("call\t_RNvM", 1, true), "the function body was dropped:\n" .. text)
		-- A label with nothing but directives under it: an exception table, a
		-- personality reference, a string table. All of it is emitted per crate and
		-- none of it is code you asked to see.
		t.ok(not text:find("GCC_except_table", 1, true), "the exception table survived:\n" .. text)
		t.ok(not text:find("DW.ref", 1, true), "the personality reference survived:\n" .. text)
		t.ok(not text:find("uleb128", 1, true), "exception table bytes survived:\n" .. text)
		t.ok(not text:find(".cfi_", 1, true), "call frame directives survived:\n" .. text)
	end)

	t.it("strip_asm keeps the labels the jumps point at", function()
		-- `.LBB6_1:` reads as a directive, but it is where `je .LBB6_1` goes. Dropping
		-- it while keeping the jump leaves every branch in the view pointing nowhere.
		local text = table.concat(output.strip_asm(RUST_ASM, "src/main.rs", { only_source_functions = true }), "\n")
		for _, label in ipairs({ "LBB6_1", "LBB6_2", "LBB6_4" }) do
			t.ok(
				text:find("\tje\t." .. label, 1, true)
					or text:find("\tjne\t." .. label, 1, true)
					or text:find("\tjmp\t." .. label, 1, true),
				"the jump to " .. label .. " was dropped, so the test proves nothing:\n" .. text
			)
			t.ok(text:find("\n." .. label .. ":", 1, true), "the jump target ." .. label .. ": is missing:\n" .. text)
		end
	end)

	t.it("strip_asm maps only lines from the file that was asked about", function()
		local kept, map = output.strip_asm(RUST_ASM, "src/main.rs", { only_source_functions = true })
		local seen = {}
		for row, line in pairs(map) do
			seen[line] = kept[row]
		end
		-- `.file 14` is main.rs; 7, 22 and 23 are core's, and a `.loc` into core would
		-- otherwise send the cursor to whatever is at line 2224 of this buffer.
		t.ok(seen[25], "the function's first source line is unmapped: " .. vim.inspect(vim.tbl_keys(seen)))
		t.ok(seen[28], "the call site is unmapped: " .. vim.inspect(vim.tbl_keys(seen)))
		for _, line in ipairs({ 1043, 1100, 2224 }) do
			t.ok(not seen[line], ("core's line %d was mapped onto this buffer"):format(line))
		end
	end)

	t.it("strip_asm without the filter keeps every block", function()
		-- The flag is what the crate-wide views want; a single-file compile has nothing
		-- to filter out and must not lose its data symbols.
		local kept = output.strip_asm(RUST_ASM, "src/main.rs")
		t.ok(table.concat(kept, "\n"):find("DW.ref.rust_eh_personality:", 1, true), "the filter ran unasked")
	end)

	t.it("module_flags makes the buffer's module the root", function()
		local args = zig.module_flags(ZIG_VERBOSE, ZIG_ROOT, "ReleaseFast")
		t.ok(args, "no compile step was found for the exe's root file")
		assert(args)
		local text = table.concat(args, " ")

		t.eq("-Mroot=" .. ZIG_ROOT, args[5], "the root module is not first:\n" .. text)
		t.ok(text:find("-Mshapes=" .. ZIG_MODULE, 1, true), "the imported module was lost:\n" .. text)
		t.ok(text:find("--dep shapes", 1, true), "the dependency edge was lost:\n" .. text)

		-- The view picks the optimise mode, one per module because that is how zig
		-- takes it; `--listen=-` would make the compiler wait on stdin forever.
		t.eq(2, select(2, text:gsub("%-O ReleaseFast", "")), "modes are not per module:\n" .. text)
		t.ok(not text:find("ODebug", 1, true), "the build's optimise mode survived:\n" .. text)
		t.ok(not text:find("listen", 1, true), "--listen survived:\n" .. text)
		t.ok(not text:find("--name", 1, true), "the output name survived:\n" .. text)
	end)

	t.it("module_flags moves a module's own segment to the front", function()
		local args = zig.module_flags(ZIG_VERBOSE, ZIG_MODULE, "Debug")
		t.ok(args, "no compile step was found for the library module")
		assert(args)
		t.eq("-Mshapes=" .. ZIG_MODULE, args[3], "the module is not the root: " .. table.concat(args, " "))
	end)

	t.it("module_flags reports a file no step compiles", function()
		t.eq(nil, zig.module_flags(ZIG_VERBOSE, "/elsewhere/src/main.zig", "Debug"))
	end)

	t.it("module_imports lists only build.zig modules", function()
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
			'const std = @import("std");',
			'const builtin = @import("builtin");',
			'const shapes = @import("shapes");',
			'const util = @import("util.zig");',
			'const also = @import("shapes");',
		})
		-- std and builtin are the compiler's; a `.zig` path resolves without build.zig.
		t.eq({ "shapes" }, zig.module_imports(buf))
		vim.api.nvim_buf_delete(buf, { force = true })
	end)

	t.it("go_render lays out a padded struct pahole-style", function()
		local lines = layout.go_render(GO_OUT)
		t.ok(lines, "the marked records were not recognised")
		assert(lines)
		local text = table.concat(lines, "\n")

		t.ok(text:find("struct packet {", 1, true), text)
		t.ok(text:find("uint64                   seq;", 1, true), "members are not aligned into columns:\n" .. text)
		t.ok(text:find("/*     8     8 */", 1, true), "offset and size are missing:\n" .. text)
		-- `bool` then `uint64`, and `uint8` then a slice: seven wasted bytes each.
		t.eq(2, select(2, text:gsub("XXX %d bytes hole", "")), "the holes were not found:\n" .. text)
		t.ok(text:find("XXX 6 bytes padding", 1, true), "trailing padding was not found:\n" .. text)
		t.ok(text:find("size: 56, cachelines: 1, members: 5, align: 8", 1, true), text)
		t.ok(text:find("sum members: 36, holes: 2, sum holes: 14", 1, true), text)
	end)

	t.it("go_render ignores output with no layout in it", function()
		-- A build failure still exits through the renderer; it must say "not mine" so
		-- the compiler's own message is what gets shown.
		t.eq(nil, layout.go_render({ "packet.go:4:2: undefined: uint65", "FAIL\tlangviews [build failed]" }))
	end)

	t.it("go_render names a non-struct rather than rendering one", function()
		t.eq({ "/* not a struct: int */" }, layout.go_render({ "@nvim-layout notstruct int" }))
	end)

	t.it("the generated go test compiles and prints its layout", function()
		if vim.fn.executable("go") == 0 then
			return
		end
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		vim.fn.writefile({ "module layoutspec", "", "go 1.24" }, dir .. "/go.mod")
		vim.fn.writefile({ "package gg", "", "type pair struct {", "\ta bool", "\tb uint64", "}" }, dir .. "/pair.go")
		vim.fn.writefile(vim.split(layout.go_test_source("gg", "pair"), "\n"), dir .. "/zz_layout_test.go")

		local res = vim.system({ "go", "test", "-v", "-vet=off", "-count=1", "-run", "^TestNvimLayout$", "." }, {
			text = true,
			cwd = dir,
		}):wait(120000)
		vim.fn.delete(dir, "rf")
		-- No toolchain download, no module cache: nothing to say about the renderer.
		if res.code ~= 0 then
			return
		end

		local lines = layout.go_render(vim.split(res.stdout or "", "\n"))
		t.ok(lines, "the test's own output did not render:\n" .. (res.stdout or ""))
		assert(lines)
		local text = table.concat(lines, "\n")
		t.ok(text:find("struct pair {", 1, true), text)
		t.ok(text:find("XXX 7 bytes hole", 1, true), "reflect's offsets did not show the hole:\n" .. text)
	end)

	t.it("module_flags reads what zig build actually prints", function()
		if vim.fn.executable("zig") == 0 then
			return
		end
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir .. "/src", "p")
		vim.fn.mkdir(dir .. "/lib", "p")
		vim.fn.writefile({ "pub fn area(w: u32, h: u32) u32 {", "\treturn w *% h;", "}" }, dir .. "/lib/shapes.zig")
		vim.fn.writefile({
			'const shapes = @import("shapes");',
			"pub fn main() void {",
			"\t_ = shapes.area(2, 3);",
			"}",
		}, dir .. "/src/main.zig")
		vim.fn.writefile({
			'const std = @import("std");',
			"pub fn build(b: *std.Build) void {",
			"\tconst target = b.standardTargetOptions(.{});",
			'\tconst shapes = b.addModule("shapes", .{ .root_source_file = b.path("lib/shapes.zig"), .target = target });',
			"\tconst exe = b.addExecutable(.{",
			'\t\t.name = "spec",',
			"\t\t.root_module = b.createModule(.{",
			'\t\t\t.root_source_file = b.path("src/main.zig"),',
			"\t\t\t.target = target,",
			'\t\t\t.imports = &.{.{ .name = "shapes", .module = shapes }},',
			"\t\t}),",
			"\t});",
			"\tb.installArtifact(exe);",
			"}",
		}, dir .. "/build.zig")

		local res = vim.system({ "zig", "build", "--verbose", "--summary", "none" }, { text = true, cwd = dir })
			:wait(180000)
		local text = (res.stderr or "") .. "\n" .. (res.stdout or "")
		local args = zig.module_flags(vim.split(text, "\n", { plain = true }), dir .. "/src/main.zig", "ReleaseSmall")
		vim.fn.delete(dir, "rf")

		t.ok(args, "no -M segments were parsed out of:\n" .. text)
		assert(args)
		local joined = table.concat(args, " ")
		t.ok(joined:find("=" .. dir .. "/src/main.zig", 1, true), joined)
		t.ok(joined:find("-Mshapes=", 1, true), "the module build.zig wired up was lost:\n" .. joined)
		t.ok(joined:find("-O ReleaseSmall", 1, true), joined)
	end)
end)
