--- Python: the interpreter's own tools, on the shared keys.
---
--- CPython's assembly is its bytecode, and `dis` prints it with source line numbers,
--- so `<leader>va` answers "what does this actually execute" the same way it does for
--- C. The rest is the project's interpreter: a `.venv` wins over whatever is on PATH,
--- because that is where the dependencies are.
---@class lang.python
local M = {}

--- Titles this adapter renders under, so the keymap can ask whether a view is
--- already on screen. Declared beside the code that uses them: a central table
--- drifts the moment an adapter gains a capability.
---@type table<string, string>
M.titles = {
	assembly = "python bytecode",
	tree = "python ast",
	check = "ruff check",
	build = "python compile",
}

local output = require("features.lang.output")
local root = require("lib.root")

local MARKERS = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt" }

--- Project root: the nearest packaging marker, else the buffer's root.
---@param buf? integer
---@return string
function M.project(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	return root.detectors.pattern(buf, MARKERS)[1] or root.get({ buf = buf })
end

--- The interpreter for this project: an activated venv, the project's `.venv`, conda,
--- then python3 on PATH.
---@param buf? integer
---@return string
function M.interpreter(buf)
	local active = os.getenv("VIRTUAL_ENV")
	if active then
		return active .. "/bin/python"
	end
	local local_venv = vim.fs.joinpath(M.project(buf), ".venv", "bin", "python")
	if vim.uv.fs_stat(local_venv) then
		return local_venv
	end
	local conda = os.getenv("CONDA_PREFIX")
	if conda then
		return conda .. "/bin/python"
	end
	local exe = vim.fn.exepath("python3")
	return exe ~= "" and exe or "python"
end

---@param buf integer
function M.run(buf)
	output.terminal({ M.interpreter(buf), vim.api.nvim_buf_get_name(buf) }, M.project(buf), { title = "python" })
end

--- pytest when the project's interpreter has it, unittest otherwise.
---@param buf integer
function M.test(buf)
	local py = M.interpreter(buf)
	local has_pytest = vim.system({ py, "-c", "import pytest" }):wait().code == 0
	local cmd = has_pytest and { py, "-m", "pytest" } or { py, "-m", "unittest", "discover" }
	output.terminal(cmd, M.project(buf), { title = has_pytest and "pytest" or "unittest" })
end

---@param buf integer
function M.check(buf)
	if not output.require_exe("ruff") then
		return
	end
	output.run({
		cmd = { "ruff", "check", "--output-format", "concise", "--no-fix", vim.api.nvim_buf_get_name(buf) },
		title = M.titles.check,
		cwd = M.project(buf),
	})
end

--- Byte-compiles without running: syntax errors, nothing else.
---@param buf integer
function M.build(buf)
	output.run({
		cmd = { M.interpreter(buf), "-m", "py_compile", vim.api.nvim_buf_get_name(buf) },
		title = M.titles.build,
		cwd = M.project(buf),
		on_lines = function(lines)
			if #lines == 1 and lines[1] == "" then
				return { "Compiles cleanly." }
			end
			return lines
		end,
	})
end

---@param buf integer
function M.build_file(buf)
	local dir = M.project(buf)
	for _, name in ipairs(MARKERS) do
		local path = vim.fs.joinpath(dir, name)
		if vim.uv.fs_stat(path) then
			vim.cmd.edit(path)
			return
		end
	end
	Snacks.notify.warn("No pyproject.toml or setup.py in " .. dir, { title = "Python" })
end

--- `foo.py` <-> `test_foo.py`, anywhere under the project.
---@param buf integer
function M.related(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	local base = vim.fs.basename(path)
	local want = base:match("^test_(.+)$") or ("test_" .. base)
	local found = vim.fs.find(want, {
		path = M.project(buf),
		type = "file",
		limit = 1,
	})[1]
	if not found then
		Snacks.notify.warn("No " .. want .. " in the project", { title = "Python" })
		return
	end
	vim.cmd.edit(found)
end

--- Maps `dis` output rows to source lines.
---
--- The line number is the first column, and only on the first instruction of each
--- line; the rows after it belong to the same line. Offsets (3.11/3.12 print them)
--- sit much further right, which is how the two are told apart.
---@param lines string[]
---@return string[] lines, table<integer, integer> map
function M.dis_lines(lines)
	local map, current = {}, nil
	for row, line in ipairs(lines) do
		if line:match("^Disassembly of") then
			current = nil
		else
			local lnum = line:match("^%s?%s?%s?%s?(%d+)%s%s")
			if lnum then
				current = tonumber(lnum)
			end
			if current and current > 0 and line:match("%S") then
				map[row] = current
			end
		end
	end
	return lines, map
end

---@param buf integer
function M.assembly(buf)
	output.run({
		cmd = { M.interpreter(buf), "-m", "dis", vim.api.nvim_buf_get_name(buf) },
		title = M.titles.assembly,
		cwd = M.project(buf),
		on_lines = M.dis_lines,
	})
end

---@param buf integer
function M.tree(buf)
	output.run({
		cmd = { M.interpreter(buf), "-m", "ast", vim.api.nvim_buf_get_name(buf) },
		title = M.titles.tree,
		filetype = "python",
		cwd = M.project(buf),
		link = false,
	})
end

return M
