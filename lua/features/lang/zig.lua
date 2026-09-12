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

--- Modules this file imports by name (`@import("mylib")`), which only build.zig wires up.
---@param buf integer
---@return string[]
function M.module_imports(buf)
	local out = {}
	for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		for name in line:gmatch('@import%("([^"]+)"%)') do
			local builtin = name == "std" or name == "builtin" or name == "root"
			if
				not builtin
				and not name:match("%.zig$")
				and not name:match("%.zon$")
				and not vim.tbl_contains(out, name)
			then
				table.insert(out, name)
			end
		end
	end
	return out
end

--- Flags the build runner passes that make no sense for a one-off emit: the output
--- name and binary, the IPC channel (`--listen=-` makes the compiler wait on stdin
--- forever), and the optimise mode, which the view chooses.
---@param args string[]
---@return string[]
local function without_build_flags(args)
	local out, skip = {}, false
	for _, arg in ipairs(args) do
		if skip then
			skip = false
		elseif arg == "--name" or arg == "-O" or arg == "--listen" then
			skip = true
		elseif not (arg:match("^%-O%u") or arg:match("^%-%-listen=") or arg:match("^%-f%a*emit%-bin")) then
			table.insert(out, arg)
		end
	end
	return out
end

--- The module arguments the build graph compiles `path` with, rearranged so `path` is
--- the root module, from `zig build --verbose` output. Nil when no compile step covers it.
---
--- Module options are positional: everything before a `-M<name>=<src>` belongs to that
--- module, and the first `-M` is the root. So the command splits into one segment per
--- module, the segment owning `path` moves to the front, and each segment gets the
--- view's `-O` since optimise mode is per module too. A file that is not a module root
--- itself (`src/util.zig` under `src/main.zig`) takes over its module's segment: same
--- imports, compiled as the root so its own functions are what gets emitted.
---@param lines string[] build runner output
---@param path string absolute path of the file
---@param mode string optimise mode, e.g. "ReleaseFast"
---@return string[]?
function M.module_flags(lines, path, mode)
	local best, best_len
	for _, line in ipairs(lines) do
		local rest = line:match("^%S*zig%s+build%-[eol]%a+%s+(.*)$")
		if rest then
			local segments, current = {}, {}
			for _, arg in ipairs(vim.split(vim.trim(rest), "%s+")) do
				table.insert(current, arg)
				if arg:match("^%-M[^=]*=") then
					table.insert(segments, current)
					current = {}
				end
			end
			for i, segment in ipairs(segments) do
				local src = segment[#segment]:match("^%-M[^=]*=(.*)$")
				local dir = vim.fs.dirname(src)
				local len = src == path and math.huge or (vim.startswith(path, dir .. "/") and #dir or nil)
				if len and (not best_len or len > best_len) then
					best_len = len
					best = { segments = segments, owner = i, global = current }
				end
			end
		end
	end
	if not best then
		return nil
	end

	local order = { best.owner }
	for i = 1, #best.segments do
		if i ~= best.owner then
			table.insert(order, i)
		end
	end
	local args = {}
	for n, i in ipairs(order) do
		local segment = without_build_flags(best.segments[i])
		if n == 1 then
			segment[#segment] = segment[#segment]:gsub("=.*$", "") .. "=" .. path
		end
		table.insert(args, "-O")
		table.insert(args, mode)
		vim.list_extend(args, segment)
	end
	return vim.list_extend(args, without_build_flags(best.global))
end

--- Calls `on_args` with the compile arguments for this file: the file alone when it
--- imports no build.zig module, otherwise the module flags the build graph uses.
---
--- `zig build --verbose` prints every compile command before running it, cached or
--- not, so its output is the build graph resolved — including options build.zig
--- computes, which no parse of build.zig could follow. It does run the build, which is
--- a no-op when nothing changed.
---@param buf integer
---@param mode string
---@param title string
---@param on_args fun(args: string[])
local function compile_args(buf, mode, title, on_args)
	local path = vim.api.nvim_buf_get_name(buf)
	local modules = M.module_imports(buf)
	if #modules == 0 then
		on_args({ "-O", mode, path })
		return
	end

	local refuse = function(why)
		Snacks.notify.warn(
			("This file imports build.zig module(s): %s.\n%s"):format(table.concat(modules, ", "), why),
			{ title = "Zig" }
		)
	end
	local dir = workspace(buf)
	if not dir then
		refuse("There is no build.zig above it to resolve them.")
		return
	end

	local jobs = require("features.lang.jobs")
	if jobs.running(title) then
		Snacks.notify.info(title .. " is already running", { title = title })
		return
	end
	local finished = jobs.start(title, "zig build")
	vim.system({ "zig", "build", "--verbose", "--summary", "none" }, { text = true, cwd = dir }, function(res)
		vim.schedule(function()
			finished()
			local text = (res.stderr or "") .. "\n" .. (res.stdout or "")
			local args = M.module_flags(vim.split(text, "\n", { plain = true }), path, mode)
			if not args then
				refuse("No step of `zig build` compiles it, so its module flags are unknown.")
				return
			end
			on_args(args)
		end)
	end)
end

--- `output.only_module` followed by a prune of the metadata it carries along.
---
--- It appends every `!DILocation` in the dump so the cursor link can resolve `!dbg`,
--- and a build-obj emit has tens of thousands of them against a few dozen kept
--- instructions — the pane is then metadata with the answer buried at the top. Only
--- the locations the kept functions actually reference are needed, plus whatever their
--- `inlinedAt:` chains point at.
---@param prefix string e.g. "main." for main.zig
---@return fun(lines: string[]): string[]
local function module_ir(prefix)
	local filter = output.only_module(prefix)
	return function(lines)
		local kept = filter(lines)
		local code, metadata = {}, {}
		local wanted = {}
		for _, line in ipairs(kept) do
			local id = line:match("^!(%d+)%s*=%s*!DILocation")
			if id then
				metadata[id] = line
			else
				table.insert(code, line)
				for ref in line:gmatch("!dbg%s+!(%d+)") do
					wanted[ref] = true
				end
			end
		end

		-- An inlined location names the call site through another !DILocation, so the
		-- reachable set has to be closed rather than read off in one pass.
		local pending = vim.tbl_keys(wanted)
		while #pending > 0 do
			local id = table.remove(pending)
			for ref in (metadata[id] or ""):gmatch("inlinedAt:%s*!(%d+)") do
				if not wanted[ref] then
					wanted[ref] = true
					table.insert(pending, ref)
				end
			end
		end

		-- Ascending id order, which is the order they were emitted in.
		local ids = {}
		for id in pairs(wanted) do
			if metadata[id] then
				table.insert(ids, id)
			end
		end
		table.sort(ids, function(a, b)
			return tonumber(a) < tonumber(b)
		end)
		for _, id in ipairs(ids) do
			table.insert(code, metadata[id])
		end
		return code
	end
end

--- Assembly for the current file.
---
--- ReleaseFast, and `-fno-emit-bin` so nothing is written next to the source: the
--- question is what the optimiser produced, not to produce an artefact.
---@param buf integer
function M.assembly(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	compile_args(buf, "ReleaseFast", M.titles.assembly, function(args)
		output.run({
			cmd = vim.list_extend({ "zig", "build-obj", "-fno-emit-bin", "-femit-asm=/dev/stdout" }, args),
			title = M.titles.assembly,
			filetype = "asm",
			cwd = cwd(buf),
			-- The whole standard library comes through a build-obj emit; only this
			-- file's own functions carry its `.loc`s.
			on_lines = function(lines)
				return output.strip_asm(lines, path, { only_source_functions = true })
			end,
		})
	end)
end

--- LLVM IR, the level above the assembly.
---@param buf integer
function M.ir(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	compile_args(buf, "ReleaseFast", M.titles.ir, function(args)
		-- Not `-femit-llvm-ir=/dev/stdout`: the IR is written with a seek, and under
		-- `vim.system` stdout is a pipe, so the view came up empty.
		local ir = output.tempfile(".ll")
		output.run({
			cmd = vim.list_extend({ "zig", "build-obj", "-fno-emit-bin", "-femit-llvm-ir=" .. ir }, args),
			title = M.titles.ir,
			filetype = "llvm",
			cwd = cwd(buf),
			artifact = ir,
			-- A build-obj emit carries all of std: a third of a million lines, of which
			-- this file's functions are a few dozen. Same filter as `ve`.
			on_lines = module_ir(vim.fn.fnamemodify(path, ":t:r") .. "."),
		})
	end)
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
	compile_args(buf, "Debug", M.titles.expand, function(args)
		local ir = output.tempfile(".ll")
		-- Symbols are prefixed with the file's stem (`main.` for main.zig), module name or not.
		local prefix = vim.fn.fnamemodify(path, ":t:r") .. "."
		output.run({
			cmd = vim.list_extend({ "zig", "build-obj", "-fno-emit-bin", "-femit-llvm-ir=" .. ir }, args),
			title = M.titles.expand,
			filetype = "llvm",
			cwd = cwd(buf),
			artifact = ir,
			on_lines = module_ir(prefix),
		})
	end)
end

return M
