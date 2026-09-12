--- Regression tests for the project generator.
---
--- The generated artefacts are what make the editor's language actions accurate — the
--- C actions read `compile_commands.json`, lua_ls reads `.luarc.json` — so a gap here
--- shows up much later as "the assembly looks wrong".
local t = require("tests.harness")
local detect = require("scaffold.detect")
local tools = require("scaffold.tools")
local templates = require("scaffold.templates")

---@param files table<string, string[]>
---@return string root
local function project(files)
	local root = vim.fn.tempname()
	for name, lines in pairs(files) do
		local path = vim.fs.joinpath(root, name)
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		vim.fn.writefile(lines, path)
	end
	return root
end

t.describe("scaffold", function()
	t.it("detects zig by build.zig and by extension", function()
		local by_marker = detect.scan(project({ ["build.zig"] = { "" }, ["src/x.txt"] = { "" } }))
		t.eq(true, by_marker.ecosystems.zig, "build.zig was not recognised")

		local by_ext = detect.scan(project({ ["src/main.zig"] = { "pub fn main() void {}" } }))
		t.eq(true, by_ext.ecosystems.zig, "a .zig file was not recognised")
	end)

	t.it("every worked-on language has build and test commands", function()
		local d = { ecosystems = { c = true, rust = true, zig = true, lua = true } }
		for _, action in ipairs({ "fmt", "fmt_check", "lint", "test", "build" }) do
			t.ok(#tools.commands(d, action) > 0, "no commands for " .. action)
		end
	end)

	t.it("a C project gets a compile-db recipe", function()
		-- Without compile_commands.json the C language actions fall back to default
		-- flags and quietly show a different program than the one that ships.
		local extras = tools.extras({ ecosystems = { c = true } })
		t.ok(extras["compile-db"], "no compile-db recipe for a C project")

		local justfile = templates.justfile({ root = "/tmp/x", ecosystems = { c = true } })
		t.ok(justfile:find("compile%-db:"), "the recipe did not reach the justfile")
		t.ok(justfile:find("bear", 1, true), "no fallback for a plain Makefile project")
	end)

	t.it("zig recipes reach the justfile", function()
		local justfile = templates.justfile({ root = "/tmp/x", ecosystems = { zig = true } })
		t.ok(justfile:find("zig build", 1, true), "no zig build recipe")
		t.ok(justfile:find("zig build test", 1, true), "no zig test recipe")
		t.ok(justfile:find("zig fmt", 1, true), "no zig fmt recipe")
	end)

	t.it("the generated build.zig names the project", function()
		local rendered = (templates.build_zig:gsub("PROJECT", "myproj"))
		t.ok(rendered:find('.name = "myproj"', 1, true), "the project name was not substituted")
		t.ok(rendered:find('b.step("run"', 1, true), "no run step for the editor's run key")
		t.ok(rendered:find('b.step("test"', 1, true), "no test step for the editor's test key")
	end)

	t.it("a lua project gets a .luarc.json that names LuaJIT", function()
		t.ok(templates.luarc:find("LuaJIT", 1, true), "the runtime is not pinned")
		t.ok(templates.luarc:find("vim", 1, true), "`vim` is not declared, so every call is undefined")
	end)

	---@param dir string
	---@param recipe string
	---@return boolean ok, string? stdout, string? stderr
	local function run_just(dir, recipe)
		local res = vim.system({ "just", recipe }, { cwd = dir, text = true }):wait(120000)
		return res.code == 0, res.stdout, res.stderr
	end

	t.it("generated C cmake recipes build, test, and generate compile-db twice", function()
		if vim.fn.executable("just") == 0 or vim.fn.executable("cmake") == 0 then
			return
		end
		local dir = project({
			["CMakeLists.txt"] = {
				"cmake_minimum_required(VERSION 3.20)",
				"project(cmakeproj C)",
				"enable_testing()",
				"add_executable(app main.c)",
				"add_test(NAME app_test COMMAND app)",
			},
			["main.c"] = { "int main(void) { return 0; }" },
		})
		local justfile = templates.justfile({ root = dir, ecosystems = { c = true } })
		vim.fn.writefile(vim.split(justfile, "\n"), dir .. "/justfile")

		local ok_build1, _, err1 = run_just(dir, "build")
		t.ok(ok_build1, "cmake build failed: " .. (err1 or ""))

		local ok_test1, _, err2 = run_just(dir, "test")
		t.ok(ok_test1, "cmake test failed: " .. (err2 or ""))

		local ok_db1, _, err3 = run_just(dir, "compile-db")
		t.ok(ok_db1, "cmake compile-db 1 failed: " .. (err3 or ""))
		t.ok(vim.uv.fs_stat(dir .. "/compile_commands.json") ~= nil, "compile_commands.json was not created")

		local ok_db2, _, err4 = run_just(dir, "compile-db")
		t.ok(ok_db2, "cmake compile-db 2 failed: " .. (err4 or ""))

		local ok_build2, _, err5 = run_just(dir, "build")
		t.ok(ok_build2, "cmake second build failed: " .. (err5 or ""))

		local ok_test2, _, err6 = run_just(dir, "test")
		t.ok(ok_test2, "cmake second test failed: " .. (err6 or ""))

		pcall(vim.fn.delete, dir, "rf")
	end)

	t.it("generated C meson recipes build, test, and generate compile-db twice", function()
		if vim.fn.executable("just") == 0 or vim.fn.executable("meson") == 0 or vim.fn.executable("ninja") == 0 then
			return
		end
		local dir = project({
			["meson.build"] = {
				"project('mesonproj', 'c')",
				"exe = executable('app', 'main.c')",
				"test('app_test', exe)",
			},
			["main.c"] = { "int main(void) { return 0; }" },
		})
		local justfile = templates.justfile({ root = dir, ecosystems = { c = true } })
		vim.fn.writefile(vim.split(justfile, "\n"), dir .. "/justfile")

		local ok_build1, _, err1 = run_just(dir, "build")
		t.ok(ok_build1, "meson build failed: " .. (err1 or ""))

		local ok_test1, _, err2 = run_just(dir, "test")
		t.ok(ok_test1, "meson test failed: " .. (err2 or ""))

		local ok_db1, _, err3 = run_just(dir, "compile-db")
		t.ok(ok_db1, "meson compile-db 1 failed: " .. (err3 or ""))
		t.ok(vim.uv.fs_stat(dir .. "/compile_commands.json") ~= nil, "compile_commands.json was not created")

		local ok_db2, _, err4 = run_just(dir, "compile-db")
		t.ok(ok_db2, "meson compile-db 2 (--reconfigure) failed: " .. (err4 or ""))

		local ok_build2, _, err5 = run_just(dir, "build")
		t.ok(ok_build2, "meson second build failed: " .. (err5 or ""))

		local ok_test2, _, err6 = run_just(dir, "test")
		t.ok(ok_test2, "meson second test failed: " .. (err6 or ""))

		pcall(vim.fn.delete, dir, "rf")
	end)

	t.it("generated C make recipes build, test, and generate compile-db twice", function()
		if vim.fn.executable("just") == 0 or vim.fn.executable("make") == 0 or vim.fn.executable("bear") == 0 then
			return
		end
		local dir = project({
			["Makefile"] = {
				"all: app",
				"app: main.c",
				"\t$(CC) -o app main.c",
				"test: app",
				"\t./app",
				"clean:",
				"\trm -f app",
				".PHONY: all test clean",
			},
			["main.c"] = { "int main(void) { return 0; }" },
		})
		local justfile = templates.justfile({ root = dir, ecosystems = { c = true } })
		vim.fn.writefile(vim.split(justfile, "\n"), dir .. "/justfile")

		local ok_build1, _, err1 = run_just(dir, "build")
		t.ok(ok_build1, "make build failed: " .. (err1 or ""))

		local ok_test1, _, err2 = run_just(dir, "test")
		t.ok(ok_test1, "make test failed: " .. (err2 or ""))

		local ok_db1, _, err3 = run_just(dir, "compile-db")
		t.ok(ok_db1, "make compile-db 1 failed: " .. (err3 or ""))
		t.ok(vim.uv.fs_stat(dir .. "/compile_commands.json") ~= nil, "compile_commands.json was not created")

		local ok_db2, _, err4 = run_just(dir, "compile-db")
		t.ok(ok_db2, "make compile-db 2 failed: " .. (err4 or ""))

		local ok_build2, _, err5 = run_just(dir, "build")
		t.ok(ok_build2, "make second build failed: " .. (err5 or ""))

		local ok_test2, _, err6 = run_just(dir, "test")
		t.ok(ok_test2, "make second test failed: " .. (err6 or ""))

		pcall(vim.fn.delete, dir, "rf")
	end)
end)
