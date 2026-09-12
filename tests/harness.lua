--- A test harness small enough to not need explaining.
---
--- Not busted: these tests drive a real editor — windows, buffers, autocmds — so they
--- have to run inside `nvim --headless` with this config loaded. Pulling in a runner
--- that wants to own the process is more trouble than twenty lines of assert.
---@class tests.harness
local M = {}

---@class tests.Result
---@field name string
---@field ok boolean
---@field err string?

---@type tests.Result[]
M.results = {}

--- Current describe() label, prefixed onto each test name.
local group = ""

---@param name string
---@param fn fun()
function M.describe(name, fn)
	local previous = group
	group = previous == "" and name or (previous .. " › " .. name)
	fn()
	group = previous
end

---@param name string
---@param fn fun()
function M.it(name, fn)
	local label = group == "" and name or (group .. " › " .. name)
	local ok, err = xpcall(fn, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	table.insert(M.results, { name = label, ok = ok, err = not ok and err or nil })
end

---@param value any
---@param message? string
function M.ok(value, message)
	if not value then
		error(message or ("expected truthy, got " .. vim.inspect(value)), 2)
	end
end

---@param expected any
---@param actual any
---@param message? string
function M.eq(expected, actual, message)
	if not vim.deep_equal(expected, actual) then
		error(
			("%s\n  expected: %s\n  actual:   %s"):format(
				message or "values differ",
				vim.inspect(expected),
				vim.inspect(actual)
			),
			2
		)
	end
end

--- A scratch buffer with `lines`, shown in the current window.
---@param lines string[]
---@param ft? string
---@return integer bufnr
function M.buffer(lines, ft)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	if ft then
		vim.bo[buf].filetype = ft
	end
	vim.api.nvim_win_set_buf(0, buf)
	return buf
end

--- A real file on disk, so anything that needs a path has one.
---@param name string
---@param lines string[]
---@return string path
function M.file(name, lines)
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local path = vim.fs.joinpath(dir, name)
	vim.fn.writefile(lines, path)
	return path
end

--- Closes every window but one and wipes scratch buffers, so one test cannot leave
--- the editor in a shape that fails the next.
function M.reset()
	-- Engine state first. A loan left outstanding by an earlier test makes the next
	-- release think it is not the last one, so the pane it created is never closed —
	-- and the failure appears in whichever spec happens to run next.
	pcall(function()
		require("features.workspace").forget_loans()
		require("features.lang.output").forget()
	end)

	local wins = vim.api.nvim_list_wins()
	for i = 2, #wins do
		pcall(vim.api.nvim_win_close, wins[i], true)
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) == "" then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end
	pcall(function()
		vim.cmd("silent! only")
	end)
end

--- Prints the report and returns the exit code.
---@return integer
function M.report()
	local failed = {}
	for _, result in ipairs(M.results) do
		if not result.ok then
			table.insert(failed, result)
		end
	end

	for _, result in ipairs(M.results) do
		print((result.ok and "  ok   " or "  FAIL ") .. result.name)
	end
	print("")
	print(("%d passed, %d failed, %d total"):format(#M.results - #failed, #failed, #M.results))

	for _, result in ipairs(failed) do
		print("")
		print("FAIL " .. result.name)
		print(result.err)
	end

	return #failed == 0 and 0 or 1
end

return M
