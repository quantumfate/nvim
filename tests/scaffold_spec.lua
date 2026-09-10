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
end)
