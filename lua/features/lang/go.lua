--- Go: the go command and the compiler's own diagnostics, on the shared keys.
---
--- Go has no macros and no separate IR you can ask for, but the compiler will tell you
--- two things that matter below the source: the assembly it emitted (`-S`) and what
--- it decided about inlining and heap escapes (`-m`). The second is usually the answer
--- to "why is this allocating".
---@class lang.go
local M = {}

--- Titles this adapter renders under, so the keymap can ask whether a view is
--- already on screen. Declared beside the code that uses them: a central table
--- drifts the moment an adapter gains a capability.
---@type table<string, string>
M.titles = {
	assembly = "go asm",
	ir = "go inlining & escapes",
	check = "go vet check",
}

local output = require("features.lang.output")
local root = require("lib.root")

local compile_cmd

--- Module root (go.work or go.mod), or the buffer's root outside a module.
---@param buf integer
---@return string
local function module(buf)
	return root.detectors.pattern(buf, { "go.work", "go.mod" })[1] or root.get({ buf = buf })
end

--- The package directory: Go compiles directories, not files.
---@param buf integer
---@return string
local function package(buf)
	return vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
end

--- Resolved path, so a symlinked checkout still matches what the compiler prints.
---@param path string
---@return string
local function real(path)
	return vim.uv.fs_realpath(path) or path
end

--- The command that compiles `file`'s package with `flag`. `go build` skips test
--- files, so a `_test.go` goes through `go test -c`, which compiles them.
---@param file string
---@param flag string
---@return string[]
function compile_cmd(file, flag)
	if file:match("_test%.go$") then
		return { "go", "test", "-c", flag, "-o", "/dev/null", "." }
	end
	return { "go", "build", flag, "-o", "/dev/null", "." }
end

---@param buf integer
function M.build(buf)
	output.terminal({ "go", "build", "./..." }, module(buf), { title = "go build" })
end

--- `go run .` in this file's package. A library package has nothing to run, so that
--- case goes to the picker instead of failing with "not a main package".
---@param buf integer
function M.run(buf)
	local first = vim.api.nvim_buf_get_lines(buf, 0, 50, false)
	for _, line in ipairs(first) do
		local name = line:match("^package%s+([%w_]+)")
		if name then
			if name == "main" then
				output.terminal({ "go", "run", "." }, package(buf), { title = "go run" })
				return
			end
			break
		end
	end
	M.run_other(buf)
end

--- Every main package in the module, to pick from.
---@param buf integer
function M.run_other(buf)
	local dir = module(buf)
	local res = vim.system(
		{ "go", "list", "-f", '{{if eq .Name "main"}}{{.Dir}}{{end}}', "./..." },
		{ cwd = dir, text = true }
	)
		:wait()
	local mains = vim.tbl_filter(function(line)
		return line ~= ""
	end, vim.split(res.stdout or "", "\n", { plain = true }))
	if #mains == 0 then
		Snacks.notify.warn("No main package in " .. dir, { title = "Go" })
		return
	end
	vim.ui.select(mains, {
		prompt = "Run package",
		format_item = function(path)
			return vim.fs.relpath(dir, path) or path
		end,
	}, function(choice)
		if choice then
			output.terminal({ "go", "run", "." }, choice, { title = "go run" })
		end
	end)
end

---@param buf integer
function M.test(buf)
	output.terminal({ "go", "test", "./..." }, module(buf), { title = "go test" })
end

---@param buf integer
function M.check(buf)
	output.run({
		cmd = { "go", "vet", "./..." },
		title = M.titles.check,
		cwd = module(buf),
		stderr = true,
		on_lines = function(lines)
			lines = vim.tbl_filter(function(line)
				return not line:match("^#")
			end, lines)
			if #lines == 0 or (#lines == 1 and lines[1] == "") then
				return { "No problems found." }
			end
			return lines
		end,
	})
end

---@param buf integer
function M.build_file(buf)
	local dir = root.detectors.pattern(buf, "go.mod")[1]
	if not dir then
		Snacks.notify.warn("No go.mod above this file", { title = "Go" })
		return
	end
	vim.cmd.edit(vim.fs.joinpath(dir, "go.mod"))
end

--- `foo.go` <-> `foo_test.go`.
---@param buf integer
function M.related(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	local other = path:match("_test%.go$") and path:gsub("_test%.go$", ".go") or path:gsub("%.go$", "_test.go")
	if not vim.uv.fs_stat(other) and not path:match("_test%.go$") then
		Snacks.notify.info("No test file yet; opening a new one", { title = "Go" })
	end
	vim.cmd.edit(other)
end

function M.tree()
	vim.cmd("InspectTree")
end

function M.reload()
	vim.cmd("LspRestart gopls")
end

--- Turns `go build -gcflags=-S` output into readable assembly for one file.
---
--- Each instruction line carries `(path:line)`, which is the cursor link for free. The
--- rest is noise for reading: FUNCDATA/PCDATA are GC and stack maps, and the hex dump
--- after each function is the machine code again. Functions from other files in the
--- package are dropped, because Go compiles the whole directory at once.
---@param file string absolute path of the source file
---@return fun(lines: string[]): string[], table<integer, integer>
function M.asm_lines(file)
	file = real(file)
	return function(lines)
		local out, map = {}, {}
		local pending, keeping = nil, false
		for _, line in ipairs(lines) do
			local header = line:match("^(%S+) STEXT")
			if header then
				pending, keeping = header, false
			else
				-- cgo positions carry the generated file too: `(cg.go:6[cg.cgo1.go:9])`.
				local path, lnum, rest = line:match("^%s+0x%x+ %d+ %((.-):(%d+)%[.-%]%)%s+(.*)$")
				if not path then
					path, lnum, rest = line:match("^%s+0x%x+ %d+ %((.-):(%d+)%)%s+(.*)$")
				end
				if not rest then
					rest = line:match("^%s+0x%x+ %d+ %(<unknown line number>%)%s+(.*)$")
				end
				if pending and path then
					keeping = real(path) == file
					if keeping then
						if #out > 0 then
							table.insert(out, "")
						end
						table.insert(out, pending .. ":")
					end
					pending = nil
				end
				if keeping and rest and not rest:match("^FUNCDATA") and not rest:match("^PCDATA") then
					table.insert(out, "\t" .. rest)
					if path and real(path) == file then
						map[#out] = tonumber(lnum)
					end
				end
			end
		end
		if #out == 0 then
			return { "No functions from this file in the output." }, map
		end
		return out, map
	end
end

---@param buf integer
function M.assembly(buf)
	local file = vim.api.nvim_buf_get_name(buf)
	output.run({
		-- `-o /dev/null` so nothing lands in the tree; the build cache replays the
		-- compiler's output, so a second press is instant.
		cmd = compile_cmd(file, "-gcflags=-S"),
		title = M.titles.assembly,
		filetype = "asm",
		cwd = package(buf),
		stderr = true,
		on_lines = M.asm_lines(file),
	})
end

--- Keeps `-m` lines for one file and maps each to its source line.
---@param file string
---@return fun(lines: string[]): string[], table<integer, integer>
function M.escape_lines(file)
	local name = vim.fs.basename(file)
	return function(lines)
		local out, map = {}, {}
		for _, line in ipairs(lines) do
			local path, lnum, col, msg = line:match("^(.-):(%d+):(%d+): (.*)$")
			if path and vim.fs.basename(path) == name then
				table.insert(out, ("%4d:%-3d %s"):format(tonumber(lnum), tonumber(col), msg))
				map[#out] = tonumber(lnum)
			end
		end
		if #out == 0 then
			return { "Nothing inlined and nothing escapes in this file." }, map
		end
		return out, map
	end
end

--- Inlining and escape analysis: which calls vanished and which values went to the heap.
---@param buf integer
function M.ir(buf)
	output.run({
		cmd = compile_cmd(vim.api.nvim_buf_get_name(buf), "-gcflags=-m"),
		title = M.titles.ir,
		cwd = package(buf),
		stderr = true,
		on_lines = M.escape_lines(vim.api.nvim_buf_get_name(buf)),
	})
end

return M
