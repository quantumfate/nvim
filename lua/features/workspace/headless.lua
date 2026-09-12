--- The project check without an editor: JSON lines on stdout, exit code from the
--- findings.
---
--- `project_check.run` is built for a person watching a statusline — it registers a
--- spinner, notifies through Snacks and publishes into `vim.diagnostic` namespaces,
--- none of which exist or matter in `--headless`. What it does have is
--- `project_check.checkers`, which is the whole decision of what to run and how to
--- parse it. So this drives those same checkers directly and formats instead of
--- publishing; the parsers stay in one place.
---
--- Nothing here waits on a UI, and the wait has a deadline: a checker whose tool hangs
--- must not hang CI, so `vim.system`'s own timeout kills it and its non-zero exit is
--- reported as "did not run".
---
---     nvim --headless -l lua/features/workspace/headless.lua [dir]
---     nvim --headless -c 'ProjectCheckJson [dir]'
---@class workspace.headless
local M = {}

--- Per-checker deadline. Long enough for a cold `cargo clippy`, short enough that a
--- stuck tool fails the run rather than owning it.
M.TIMEOUT_MS = 300000

---@type table<integer, string>
local SEVERITY = {
	[vim.diagnostic.severity.ERROR] = "error",
	[vim.diagnostic.severity.WARN] = "warning",
	[vim.diagnostic.severity.INFO] = "info",
	[vim.diagnostic.severity.HINT] = "hint",
}

---@class workspace.headless.Record
---@field file string
---@field lnum integer 1-based
---@field col integer 1-based
---@field severity string error|warning|info|hint
---@field source string Checker name
---@field message string
---@field code? string

--- One finding as a record. Severity is spelled out rather than numbered: the number is
--- a Neovim enum, and whatever reads this is not Neovim.
---@param item workspace.CheckItem
---@param source string
---@return workspace.headless.Record
function M.record(item, source)
	return {
		file = item.filename,
		lnum = item.lnum,
		col = item.col,
		severity = SEVERITY[item.severity] or "warning",
		source = source,
		message = item.message,
		code = item.code,
	}
end

--- A checker that could not check, as an error record. Zero findings from a tool that
--- never ran is the one result that must not look clean.
---@param source string
---@param reason string
---@param dir string
---@return workspace.headless.Record
function M.failure(source, reason, dir)
	return {
		file = dir,
		lnum = 1,
		col = 1,
		severity = "error",
		source = source,
		message = ("%s did not run: %s"):format(source, reason),
	}
end

--- `records` as JSON lines, in a stable order so two runs of a clean tree diff empty.
---@param records workspace.headless.Record[]
---@return string
function M.encode(records)
	local sorted = vim.deepcopy(records)
	table.sort(sorted, function(a, b)
		if a.file ~= b.file then
			return a.file < b.file
		end
		if a.lnum ~= b.lnum then
			return a.lnum < b.lnum
		end
		if a.col ~= b.col then
			return a.col < b.col
		end
		return a.message < b.message
	end)
	local out = {}
	for _, record in ipairs(sorted) do
		table.insert(out, vim.json.encode(record))
	end
	return #out == 0 and "" or (table.concat(out, "\n") .. "\n")
end

--- Errors fail the run; warnings do not. A gate that went red on every hint would be
--- turned off within a week, and these tools are generous with hints.
---@param records workspace.headless.Record[]
---@return integer
function M.exit_code(records)
	for _, record in ipairs(records) do
		if record.severity == "error" then
			return 1
		end
	end
	return 0
end

--- Runs every applicable checker for `dir` and calls `done` with the records.
---@param dir string
---@param done fun(records: workspace.headless.Record[])
function M.collect(dir, done)
	local check = require("features.workspace.project_check")
	-- The checkers derive the project from a buffer; an unnamed one makes that the cwd.
	vim.cmd.lcd({ dir, mods = { silent = true } })
	local checkers = check.checkers(vim.api.nvim_get_current_buf())
	local records, pending = {}, #checkers
	if pending == 0 then
		return done(records)
	end
	for _, checker in ipairs(checkers) do
		local function finish(res)
			local ok, items, failure = pcall(checker.parse, res)
			if checker.cleanup then
				pcall(checker.cleanup)
			end
			if not ok then
				failure, items = tostring(items), {}
			elseif res.code == 124 then
				failure = failure or ("timed out after %ds"):format(M.TIMEOUT_MS / 1000)
			end
			if failure then
				table.insert(records, M.failure(checker.name, failure, checker.cwd))
			end
			for _, item in ipairs(items or {}) do
				table.insert(records, M.record(item, checker.name))
			end
			pending = pending - 1
		end

		local opts = { text = true, cwd = checker.cwd, timeout = M.TIMEOUT_MS }
		local ok, err = pcall(vim.system, checker.cmd, opts, function(res)
			vim.schedule(function()
				finish(res)
			end)
		end)
		if not ok then
			finish({ code = 1, signal = 0, stdout = "", stderr = tostring(err) })
		end
	end
	-- Poll rather than schedule a callback chain: this is the whole process's job.
	vim.wait(M.TIMEOUT_MS + 30000, function()
		return pending == 0
	end, 100)
	done(records)
end

--- Runs the check over `dir`, writes the JSON lines to stdout and returns the exit code.
---@param dir? string Defaults to the cwd
---@return integer
function M.main(dir)
	local code = 0
	M.collect(vim.fs.normalize(dir and vim.fn.fnamemodify(dir, ":p") or assert(vim.uv.cwd())), function(records)
		-- io.stdout, not print(): print goes through the message system, which in
		-- headless mode interleaves with notifications and drops the last newline
		-- before an immediate exit.
		io.stdout:write(M.encode(records))
		io.stdout:flush()
		code = M.exit_code(records)
	end)
	return code
end

--- Registers `:ProjectCheckJson [dir]`, which exits the editor with the check's code.
function M.setup()
	vim.api.nvim_create_user_command("ProjectCheckJson", function(args)
		local code = M.main(args.fargs[1])
		-- `:qa!` always exits 0, so a failing check would look clean to the caller.
		vim.cmd(code == 0 and "qa!" or ("cquit " .. code))
	end, { nargs = "?", complete = "dir", desc = "Project check as JSON lines, then exit" })
end

-- Run as a script: `nvim --headless -l lua/features/workspace/headless.lua [dir]`.
-- `arg` is set only by `-l`, and arg[0] is the script it was given.
if type(_G.arg) == "table" and type(_G.arg[0]) == "string" and _G.arg[0]:match("headless%.lua$") then
	os.exit(M.main(_G.arg[1]))
end

return M
