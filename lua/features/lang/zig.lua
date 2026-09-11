--- Zig: the compiler's own emit flags, on the shared keys.
---
--- Zig needs no build system detection — `build.zig` or nothing — and it emits IR and
--- assembly directly, which makes it the least ceremonious of the four.
---@class lang.zig
local M = {}

--- Titles this adapter renders under, so the keymap can ask whether a view is
--- already on screen. Declared beside the code that uses them: a central table
--- drifts the moment an adapter gains a capability.
---@type table<string, string>
M.titles = {
	expand = "zig comptime (debug ir)",
	assembly = "zig asm",
	ir = "zig llvm-ir",
	check = "zig check",
}

local output = require("features.lang.output")
local root = require("lib.root")

local standalone

--- Nearest directory containing build.zig, or nil for a standalone file. The pattern
--- detector stops at the first match rather than falling back to cwd, which is what
--- makes "is this a workspace?" answerable.
---@param buf integer
---@return string?
local function workspace(buf)
	return root.detectors.pattern(buf, "build.zig")[1]
end

---@param buf integer
---@return string
local function cwd(buf)
	return workspace(buf) or root.get({ buf = buf })
end

---@param buf integer
function M.build(buf)
	if workspace(buf) then
		output.terminal({ "zig", "build" }, cwd(buf), { title = "zig" })
	else
		output.terminal({ "zig", "build-exe", vim.api.nvim_buf_get_name(buf) }, cwd(buf), { title = "zig" })
	end
end

--- Workspaces route through build.zig; lone files compile and run directly.
---@param buf integer
function M.run(buf)
	if workspace(buf) then
		output.terminal({ "zig", "build", "run" }, cwd(buf), { title = "zig" })
	else
		output.terminal({ "zig", "run", vim.api.nvim_buf_get_name(buf) }, cwd(buf), { title = "zig" })
	end
end

---@param buf integer
function M.test(buf)
	if workspace(buf) then
		output.terminal({ "zig", "build", "test" }, cwd(buf), { title = "zig" })
	else
		output.terminal({ "zig", "test", vim.api.nvim_buf_get_name(buf) }, cwd(buf), { title = "zig" })
	end
end

--- Parse and AST-check without compiling; the fastest way to find a syntax error.
---@param buf integer
function M.check(buf)
	output.run({
		cmd = { "zig", "ast-check", vim.api.nvim_buf_get_name(buf) },
		title = M.titles.check,
		cwd = cwd(buf),
		on_lines = function(lines)
			-- ast-check says nothing on success, which reads as a broken command.
			if #lines == 1 and lines[1] == "" then
				return { "No problems found." }
			end
			return lines
		end,
	})
end

---@param buf integer
function M.build_file(buf)
	local dir = workspace(buf)
	if not dir then
		Snacks.notify.warn("No build.zig above this file", { title = "Zig" })
		return
	end
	vim.cmd.edit(vim.fs.joinpath(dir, "build.zig"))
end

--- Modules this file imports by name (`@import("mylib")`), which only build.zig wires up.
---@param buf integer
---@return string[]
function M.module_imports(buf)
	local out = {}
	for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		for name in line:gmatch('@import%("([^"]+)"%)') do
			local builtin = name == "std" or name == "builtin" or name == "root"
			if not builtin and not name:match("%.zig$") and not name:match("%.zon$") and not vim.tbl_contains(out, name) then
				table.insert(out, name)
			end
		end
	end
	return out
end

--- False, with a notification, when the file cannot compile on its own. The views run
--- `zig build-obj` on the single file, which knows nothing of build.zig's modules and
--- fails with "no module named".
---@param buf integer
---@return boolean
function standalone(buf)
	local modules = M.module_imports(buf)
	if #modules == 0 then
		return true
	end
	Snacks.notify.warn(
		("This file imports build.zig module(s): %s.\nThe views compile the file alone and cannot resolve them."):format(
			table.concat(modules, ", ")
		),
		{ title = "Zig" }
	)
	return false
end

--- Assembly for the current file.
---
--- ReleaseFast, and `-fno-emit-bin` so nothing is written next to the source: the
--- question is what the optimiser produced, not to produce an artefact.
---@param buf integer
function M.assembly(buf)
	if not standalone(buf) then
		return
	end
	local path = vim.api.nvim_buf_get_name(buf)
	output.run({
		cmd = { "zig", "build-obj", "-O", "ReleaseFast", "-fno-emit-bin", "-femit-asm=/dev/stdout", path },
		title = M.titles.assembly,
		filetype = "asm",
		cwd = cwd(buf),
		on_lines = function(lines)
			return output.strip_asm(lines, path)
		end,
	})
end

--- LLVM IR, the level above the assembly.
---@param buf integer
function M.ir(buf)
	if not standalone(buf) then
		return
	end
	local path = vim.api.nvim_buf_get_name(buf)
	output.run({
		cmd = { "zig", "build-obj", "-O", "ReleaseFast", "-fno-emit-bin", "-femit-llvm-ir=/dev/stdout", path },
		title = M.titles.ir,
		filetype = "llvm",
		cwd = cwd(buf),
	})
end

--- Zig's answer to "what does this expand to".
---
--- There is no preprocessor to run, but `comptime` is still a compile-time expansion:
--- generics get instantiated, `inline for` gets unrolled, `comptime` blocks get
--- evaluated away. Debug-mode LLVM IR is where that becomes visible — before the
--- optimiser rewrites it into something unrecognisable, which is what `vi` shows.
---
--- So the two views answer different questions: this one is what comptime produced,
--- `vi` is what the optimiser did with it.
---
--- `--verbose-air` would be the ideal answer and prints nothing on a release build of
--- the compiler, which is how every distro ships it.
---@param buf integer
function M.expand(buf)
	if not standalone(buf) then
		return
	end
	local path = vim.api.nvim_buf_get_name(buf)
	local ir = output.tempfile(".ll")
	-- The module prefix Zig gives this file's symbols, e.g. `main.` for main.zig.
	local prefix = vim.fn.fnamemodify(path, ":t:r") .. "."
	output.run({
		cmd = { "zig", "build-obj", "-O", "Debug", "-fno-emit-bin", "-femit-llvm-ir=" .. ir, path },
		title = M.titles.expand,
		filetype = "llvm",
		cwd = cwd(buf),
		artifact = ir,
		on_lines = output.only_module(prefix),
	})
end

return M
