--- Semantic checkers a kernel patch is judged by: sparse and coccinelle.
---
--- Neither is a compiler warning. sparse understands the kernel's own annotations
--- (`__user`, `__rcu`, endianness, bitwise types), coccinelle matches API misuse
--- across a whole subsystem. Both are driven through the tree's build so the file is
--- checked with the flags it is really compiled with.
---@class sys.semantic
local M = {}

local util = require("features.sys.util")

--- Both streams of a finished command, in order of stream: sparse and spatch report on
--- stderr while exiting 0, so `util.lines` (stderr only on failure) loses everything.
---@param res vim.SystemCompleted
---@return string[]
local function both(res)
	local text = (res.stdout or "") .. "\n" .. (res.stderr or "")
	return vim.split(vim.trim(text), "\n", { plain = true })
end

--- A path as printed, made absolute against the tree the tool ran in.
---@param file string
---@param dir string
---@return string
local function absolute(file, dir)
	file = file:gsub("^%./", "")
	return file:sub(1, 1) == "/" and file or vim.fs.joinpath(dir, file)
end

--- Parses `sparse` output into quickfix items.
---
--- A diagnostic is `file:line:col: warning|error: message`. The lines under a type
--- mismatch (`file:line:col:    expected int x`) have no severity word and belong to
--- the diagnostic above them, so they are kept as notes rather than dropped: the
--- mismatch is unreadable without the two types.
---@param lines string[]
---@param dir string Directory the tool ran in, for relative paths
---@return table[]
function M.parse_sparse(lines, dir)
	local items = {}
	for _, line in ipairs(lines) do
		local file, lnum, col, rest = line:match("^(.-):(%d+):(%d+):%s+(.*)$")
		if file then
			local kind, msg = rest:match("^(%a+):%s*(.*)$")
			local type = kind == "error" and "E" or kind == "warning" and "W" or "I"
			-- `note:` and the unlabelled continuation lines are both notes.
			if kind ~= "error" and kind ~= "warning" then
				msg = rest
			end
			table.insert(items, {
				filename = absolute(file, dir),
				lnum = tonumber(lnum),
				col = tonumber(col),
				text = msg,
				type = type,
			})
		end
	end
	return items
end

--- Parses `spatch`/`make coccicheck MODE=report` output into quickfix items.
---
--- Report mode prints `file:line:col-endcol: message`; a python rule that reports a
--- bare position prints no end column. Everything else the target prints (progress,
--- the false-positive banner) has no location and is skipped.
---@param lines string[]
---@param dir string
---@return table[]
function M.parse_cocci(lines, dir)
	local items = {}
	for _, line in ipairs(lines) do
		local file, lnum, col, end_col, msg = line:match("^(.-):(%d+):(%d+)%-(%d+):%s+(.*)$")
		if not file then
			file, lnum, col, msg = line:match("^(.-):(%d+):(%d+):%s+(.*)$")
		end
		if file and msg ~= "" then
			table.insert(items, {
				filename = absolute(file, dir),
				lnum = tonumber(lnum),
				col = tonumber(col) + 1, -- spatch counts columns from 0
				end_col = end_col and (tonumber(end_col) + 1) or nil,
				text = msg,
				type = "W",
			})
		end
	end
	return items
end

--- Fills the quickfix list and says what came of it, the way the other sys tools do.
---@param items table[]
---@param title string
---@param clean string
local function report(items, title, clean)
	vim.fn.setqflist({}, " ", { title = title, items = items })
	if #items == 0 then
		Snacks.notify.info(clean, { title = "Semantic" })
	else
		require("features.workspace").dock().open("quickfix")
	end
end

--- The sparse command for a file: the tree's own build inside a kernel tree, the
--- file's recorded compile flags outside one.
---
--- `C=2` rather than `C=1`: `C=1` only checks what it recompiles, so the second run on
--- an unchanged file reported nothing at all.
---@param buf integer
---@return string[] cmd, string dir
function M.sparse_cmd(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	local tree = require("features.sys.kernel").tree(buf)
	if tree then
		local object = vim.fs.relpath(tree, path):gsub("%.[cS]$", ".o")
		return { "make", "C=2", object }, tree
	end
	-- Same flags the file is compiled with, with sparse in the compiler's place.
	local cmd, dir = require("features.lang.c").invocation(buf, {})
	cmd[1] = "sparse"
	return cmd, dir
end

--- sparse on the current file, findings to quickfix.
---@param buf integer
function M.sparse(buf)
	if vim.fn.executable("sparse") == 0 then
		Snacks.notify.warn("sparse is not installed", { title = "Semantic" })
		return
	end
	local path = vim.api.nvim_buf_get_name(buf)
	if not path:match("%.[ch]$") and not path:match("%.S$") then
		Snacks.notify.warn("sparse only checks C sources", { title = "Semantic" })
		return
	end
	local cmd, dir = M.sparse_cmd(buf)
	util.chain("sparse", { { cmd = cmd, cwd = dir } }, function(results)
		local items = M.parse_sparse(both(results[1]), dir)
		report(items, "sparse " .. vim.fs.basename(path), "sparse: clean")
	end)
end

--- The tree's coccinelle scripts, by name, so the picker shows `api/alloc/kzalloc`
--- rather than fifty bare basenames.
---@param tree string
---@return string[] paths
function M.scripts(tree)
	local dir = vim.fs.joinpath(tree, "scripts", "coccinelle")
	local found = vim.fs.find(function(name)
		return name:match("%.cocci$")
	end, { path = dir, type = "file", limit = math.huge })
	table.sort(found)
	return found
end

--- Runs one coccinelle script over the current file and collects its report.
---@param buf integer
---@param script string
---@param tree? string Kernel tree, when the file is inside one
function M.run_script(buf, script, tree)
	local path = vim.api.nvim_buf_get_name(buf)
	local name = vim.fn.fnamemodify(script, ":t:r")
	tree = tree or require("features.sys.kernel").tree(buf)
	local cmd, dir
	if tree then
		-- The tree's target knows the include paths, the python helpers and the
		-- spatch flags each script wants; `M=` limits it to this file's directory.
		cmd = {
			"make",
			"coccicheck",
			"COCCI=" .. script,
			"MODE=report",
			"M=" .. vim.fs.relpath(tree, vim.fs.dirname(path)),
		}
		dir = tree
	else
		cmd = { "spatch", "--very-quiet", "-D", "report", "--sp-file", script, path }
		dir = vim.fs.dirname(path)
	end
	util.chain("coccicheck", { { cmd = cmd, cwd = dir } }, function(results)
		local items = M.parse_cocci(both(results[1]), dir)
		if tree then
			-- `M=` checks the whole directory; only this file was asked about.
			items = vim.tbl_filter(function(item)
				return item.filename == path
			end, items)
		end
		report(items, "coccicheck " .. name, "coccicheck " .. name .. ": clean")
	end)
end

--- Picks a coccinelle script and runs it in report mode over the current file.
---@param buf integer
function M.cocci(buf)
	local tree = require("features.sys.kernel").tree(buf)
	if tree then
		local scripts = M.scripts(tree)
		if #scripts == 0 then
			Snacks.notify.warn("No scripts/coccinelle/*.cocci in this tree", { title = "Semantic" })
			return
		end
		vim.ui.select(scripts, {
			prompt = "coccicheck",
			format_item = function(item)
				return (vim.fs.relpath(vim.fs.joinpath(tree, "scripts", "coccinelle"), item):gsub("%.cocci$", ""))
			end,
		}, function(choice)
			if choice then
				M.run_script(buf, choice, tree)
			end
		end)
		return
	end
	if vim.fn.executable("spatch") == 0 then
		Snacks.notify.warn("spatch is not installed", { title = "Semantic" })
		return
	end
	local script = vim.fn.input("Semantic patch (.cocci): ", "", "file")
	if script ~= "" then
		M.run_script(buf, vim.fn.fnamemodify(script, ":p"))
	end
end

return M
