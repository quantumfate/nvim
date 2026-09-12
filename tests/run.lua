--- Runs every spec, each in its own nvim, and exits non-zero on failure.
---
---     nvim --headless -n -c "luafile tests/run.lua"
---     TEST_SPECS=tests/workspace_spec.lua nvim --headless -n -c "luafile tests/run.lua"
---
--- One process per spec: sharing an editor let one spec's windows, loans and autocmds
--- fail another spec, and a segfault in one took the whole suite down. The same file
--- is the child entry point, selected by TEST_CHILD_SPEC.
local t = require("tests.harness")

-- Tests write files and never want them reformatted. Formatting inside BufWritePre also
-- segfaults nvim in buf_write after some earlier test state (stylua via conform; not
-- reproducible outside a long headless run).
vim.g.disable_autoformat = true

--- `:cquit` sets the exit status; `:qa!` always exits 0, which makes a failing suite
--- look green to anything checking the code.
---@param code integer
local function exit(code)
	vim.cmd(code == 0 and "qa!" or ("cquit " .. code))
end

--- Child: runs one spec and streams results as JSON lines, one per test, so a crash
--- mid-spec still leaves the finished tests and the one that was running on disk.
---@param spec string
---@param out_path string
local function child(spec, out_path)
	local out = assert(io.open(out_path, "w"))
	local function emit(record)
		out:write(vim.json.encode(record), "\n")
		out:flush()
	end

	local it = t.it
	t.it = function(name, fn)
		emit({ start = name })
		it(name, fn)
		local r = t.results[#t.results]
		emit({ name = r.name, ok = r.ok, err = r.err })
	end

	local ok, err = pcall(dofile, spec)
	if not ok then
		emit({ name = spec .. " (failed to load)", ok = false, err = tostring(err) })
	end
	emit({ done = true })
	out:close()
	exit(0)
end

local child_spec = os.getenv("TEST_CHILD_SPEC")
if child_spec then
	child(child_spec, assert(os.getenv("TEST_CHILD_OUT")))
	return
end

-- Each child is a full editor with every plugin loaded; memory, not cores, is the limit.
local JOBS = math.max(1, math.min(4, math.floor(vim.uv.available_parallelism() / 2)))
local TIMEOUT_MS = (tonumber(os.getenv("TEST_TIMEOUT")) or 300) * 1000

--- Accepts `workspace`, `workspace_spec` or a path.
---@param arg string
---@return string
local function spec_path(arg)
	if arg:find("/") or arg:match("%.lua$") then
		return arg
	end
	return ("tests/%s.lua"):format(arg:match("_spec$") and arg or (arg .. "_spec"))
end

local specs = {}
local selected = os.getenv("TEST_SPECS")
if selected and selected ~= "" then
	for arg in selected:gmatch("%S+") do
		local path = spec_path(arg)
		if vim.fn.filereadable(path) == 0 then
			io.stderr:write("no such spec: " .. path .. "\n")
			exit(2)
			return
		end
		table.insert(specs, path)
	end
else
	specs = vim.fn.glob("tests/*_spec.lua", false, true)
end

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")

---@class tests.Run
---@field spec string
---@field out string
---@field started number
---@field done? vim.SystemCompleted
---@field secs? number

---@type tests.Run[]
local runs = {}
local next_index, running = 1, 0

local function launch()
	while running < JOBS and next_index <= #specs do
		local spec = specs[next_index]
		local run = { spec = spec, out = ("%s/%d.jsonl"):format(tmp, next_index), started = vim.uv.hrtime() }
		runs[next_index] = run
		next_index, running = next_index + 1, running + 1

		-- -i NONE: parallel children would otherwise race writing one shada file.
		vim.system({ vim.v.progpath, "--headless", "-n", "-i", "NONE", "-c", "luafile tests/run.lua" }, {
			env = { TEST_CHILD_SPEC = spec, TEST_CHILD_OUT = run.out, TEST_SPECS = "" },
			timeout = TIMEOUT_MS,
			text = true,
		}, function(result)
			vim.schedule(function()
				run.done, run.secs = result, (vim.uv.hrtime() - run.started) / 1e9
				running = running - 1
				io.stderr:write(("  %-28s %5.1fs\n"):format(vim.fs.basename(spec), run.secs))
				launch()
			end)
		end)
	end
end

local started = vim.uv.hrtime()
launch()
vim.wait(TIMEOUT_MS * #specs, function()
	return running == 0 and next_index > #specs
end, 100)

--- Folds one child's result file and exit status into the harness results.
---@param run tests.Run
local function collect(run)
	local finished, current = false, nil
	local f = io.open(run.out, "r")
	if f then
		for line in f:lines() do
			local ok, record = pcall(vim.json.decode, line)
			if ok and record.done then
				finished = true
			elseif ok and record.start then
				current = record.start
			elseif ok then
				current = nil
				table.insert(
					t.results,
					{ name = record.name, ok = record.ok, err = record.err ~= vim.NIL and record.err or nil }
				)
			end
		end
		f:close()
	end

	local r = run.done
	if not r then
		return
	end
	if finished and r.code == 0 and r.signal == 0 then
		return
	end

	local cause = r.code == 124 and ("timed out after %ds"):format(TIMEOUT_MS / 1000)
		or r.signal ~= 0 and ("killed by signal %d"):format(r.signal)
		or ("exited %d before finishing"):format(r.code)
	local output = vim.trim((r.stdout or "") .. "\n" .. (r.stderr or ""))
	local tail = vim.list_slice(vim.split(output, "\n"), math.max(1, #vim.split(output, "\n") - 20))
	table.insert(t.results, {
		name = ("%s (%s%s)"):format(run.spec, cause, current and (", during: " .. current) or ""),
		ok = false,
		err = table.concat(tail, "\n"),
	})
end

for _, run in ipairs(runs) do
	collect(run)
end
vim.fn.delete(tmp, "rf")

print("")
local code = t.report()
-- Not print(): its trailing newline is lost when `:cquit` follows immediately.
io.stdout:write(("\n%d specs in %.1fs, %d at a time\n"):format(#specs, (vim.uv.hrtime() - started) / 1e9, JOBS))
io.stdout:flush()
exit(code)
