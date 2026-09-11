--- Small pieces the systems tools share: running a chain of commands with the
--- statusline spinner, and finding the name under the cursor.
---@class sys.util
local M = {}

--- Runs commands one after another, stopping at the first failure. The spinner covers
--- the whole chain, since "compile then inspect" is one wait from where you sit.
---@param title string
---@param steps { cmd: string[], cwd?: string, env?: table<string, string> }[]
---@param done fun(results: vim.SystemCompleted[])
function M.chain(title, steps, done)
	local jobs = require("features.lang.jobs")
	if jobs.running(title) then
		Snacks.notify.info(title .. " is already running", { title = title })
		return
	end
	local finished = jobs.start(title, steps[1].cmd[1])
	local results = {}

	local function step(i)
		local s = steps[i]
		vim.system(s.cmd, { text = true, cwd = s.cwd, env = s.env }, function(res)
			vim.schedule(function()
				table.insert(results, res)
				if res.code ~= 0 or i == #steps then
					finished()
					done(results)
				else
					step(i + 1)
				end
			end)
		end)
	end
	step(1)
end

--- Lines of a completed command, stderr first when it failed.
---@param res vim.SystemCompleted
---@return string[]
function M.lines(res)
	local text = res.stdout or ""
	if res.code ~= 0 then
		text = (res.stderr or "") .. "\n" .. text
	end
	return vim.split(vim.trim(text), "\n", { plain = true })
end

--- The binary to inspect from `buf`: one named after the file (`syscalls.c` ->
--- `syscalls`) when it was built, otherwise the project's remembered choice.
---
--- The remembered choice alone was wrong in practice: profile `hot`, open
--- `syscalls.c`, press strace, and `hot` got traced without a word.
---@param buf integer
---@param on_pick fun(path: string)
function M.binary(buf, on_pick)
	local binary = require("features.lang.binary")
	local root = require("lib.root").get({ buf = buf })
	local stem = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t:r")
	if stem ~= "" then
		for _, path in ipairs(binary.candidates(root)) do
			if vim.fs.basename(path) == stem then
				on_pick(path)
				return
			end
		end
	end
	binary.select(root, {}, on_pick)
end

--- Toggle helper: closes the view when it is showing, otherwise runs `open`.
---@param title string
---@param open fun()
function M.toggle(title, open)
	local output = require("features.lang.output")
	if output.showing(title) then
		output.close(title)
	else
		open()
	end
end

--- Function types across the grammars this config ships.
---@type table<string, true>
local FUNCTIONS = {
	function_definition = true,
	function_item = true,
	function_declaration = true,
	method_declaration = true,
	method_definition = true,
}

--- The name of the function around the cursor, or nil.
---@param buf integer
---@return string?
function M.function_name(buf)
	local node = vim.treesitter.get_node({ bufnr = buf })
	while node and not FUNCTIONS[node:type()] do
		node = node:parent()
	end
	if not node then
		return nil
	end
	local name = node:field("name")[1]
	if not name then
		-- C: the name sits at the bottom of the declarator chain.
		local d = node:field("declarator")[1]
		while d and (d:field("declarator")[1] or d:field("name")[1]) do
			d = d:field("declarator")[1] or d:field("name")[1]
		end
		name = d
	end
	if not name then
		for child in node:iter_children() do
			if child:type() == "identifier" then
				name = child
				break
			end
		end
	end
	return name and vim.treesitter.get_node_text(name, buf) or nil
end

return M
