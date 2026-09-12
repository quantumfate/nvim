--- Runs the project's binary and turns whatever it crashed with into a walkable list.
---
--- The runtimes are told to be loud first: ASan symbolises and keeps going to print
--- the allocation stack, UBSan prints a stack trace, Rust prints a backtrace, Go dumps
--- every goroutine. Output is merged so the report reads in the order it happened.
---@class sys.run
local M = {}

M.title = "run log"

--- Environment that makes crash reports complete.
---@type table<string, string>
M.ENV = {
	ASAN_OPTIONS = "symbolize=1:detect_leaks=1:abort_on_error=0:print_legend=0",
	UBSAN_OPTIONS = "print_stacktrace=1:halt_on_error=0",
	TSAN_OPTIONS = "second_deadlock_stack=1",
	RUST_BACKTRACE = "1",
	GOTRACEBACK = "all",
	PYTHONFAULTHANDLER = "1",
}

--- Signal names for the notification, from the exit status the shell reports.
---@type table<integer, string>
local SIGNALS = { [4] = "SIGILL", [6] = "SIGABRT", [7] = "SIGBUS", [8] = "SIGFPE", [11] = "SIGSEGV" }

---@param buf integer
function M.run(buf)
	local root = require("lib.root").get({ buf = buf })
	require("features.sys.util").binary(buf, function(bin)
		local env = vim.tbl_extend("force", vim.fn.environ(), M.ENV)
		require("features.sys.util").chain(M.title, {
			-- `exec` so the signal is the program's, not the shell's.
			{ cmd = { "sh", "-c", 'exec "$0" 2>&1', bin }, cwd = root, env = env },
		}, function(results)
			local res = results[1]
			local lines = vim.split(vim.trim(res.stdout or ""), "\n", { plain = true })
			require("features.lang.output").show({ title = M.title, lines = lines, source = buf, link = false })

			local stack = require("features.sys.stack")
			local located =
				stack.to_quickfix(stack.parse(lines, { cwd = root, root = root }), "Run: " .. vim.fs.basename(bin))
			local status = res.signal and res.signal ~= 0 and (SIGNALS[res.signal] or ("signal " .. res.signal))
				or ("exit " .. res.code)
			if located > 0 then
				Snacks.notify.warn(
					("%s — %d frame(s) in quickfix; ]q to walk"):format(status, located),
					{ title = "Run" }
				)
			elseif res.code ~= 0 then
				Snacks.notify.warn(status, { title = "Run" })
			end
		end)
	end)
end

--- Checks whether the kernel perf_event_paranoid setting allows unprivileged rr recording.
---@return boolean ok, integer paranoid
function M.check_rr_paranoid()
	local ok, content = pcall(vim.fn.readfile, "/proc/sys/kernel/perf_event_paranoid")
	local val = ok and tonumber(content[1]) or 2
	return val <= 1, val
end

--- Records the binary with rr into a trace.
---@param buf integer
---@param args? string[]
function M.rr_record(buf, args)
	if vim.fn.executable("rr") == 0 then
		Snacks.notify.warn("rr is not installed", { title = "rr record" })
		return
	end
	local ok, paranoid = M.check_rr_paranoid()
	if not ok then
		Snacks.notify.warn(
			("rr requires kernel.perf_event_paranoid <= 1 (current: %d)\nRun: sudo sysctl kernel.perf_event_paranoid=1\nOr enable nvim_enable_rr in the ansible role"):format(
				paranoid
			),
			{ title = "rr record" }
		)
		return
	end

	local root = require("lib.root").get({ buf = buf })
	require("features.sys.util").binary(buf, function(bin)
		local cmd = { "rr", "record", bin }
		if args and #args > 0 then
			vim.list_extend(cmd, args)
		end
		require("features.lang.output").terminal(cmd, root, {
			title = "rr record · " .. vim.fs.basename(bin),
		})
	end)
end

--- Replays the latest rr recording with an interactive gdb server or terminal.
---@param buf integer
function M.rr_replay(buf)
	if vim.fn.executable("rr") == 0 then
		Snacks.notify.warn("rr is not installed", { title = "rr replay" })
		return
	end
	local root = require("lib.root").get({ buf = buf })
	require("features.lang.output").terminal({ "rr", "replay" }, root, {
		title = "rr replay",
	})
end

return M
