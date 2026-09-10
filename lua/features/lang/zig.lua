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

--- Assembly for the current file.
---
--- ReleaseFast, and `-fno-emit-bin` so nothing is written next to the source: the
--- question is what the optimiser produced, not to produce an artefact.
---@param buf integer
function M.assembly(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	output.run({
		cmd = { "zig", "build-obj", "-O", "ReleaseFast", "-fno-emit-bin", "-femit-asm=/dev/stdout", path },
		title = M.titles.assembly,
		filetype = "asm",
		cwd = cwd(buf),
		on_lines = output.strip_asm,
	})
end

--- LLVM IR, the level above the assembly.
---@param buf integer
function M.ir(buf)
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
