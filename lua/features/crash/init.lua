--- Reading crashes without leaving the editor.
---
--- A segfault is a stack trace pointing at your source, which is exactly the kind of
--- thing an editor should be able to open. systemd-coredump already captured it and gdb
--- can already symbolise it; what was missing is the two-step of finding the dump and
--- turning "at crash.c:7" into a cursor position.
---
--- Three entry points:
---   :Crashes      pick from recent core dumps
---   :CrashOpen    a core file by path, for one systemd did not capture
---   :CrashDecode  symbolise a kernel oops pasted into a buffer
---@class crash
local M = {}

local report = require("features.crash.report")

--- Signal numbers worth naming. The rest are shown as bare numbers.
---@type table<integer, string>
local SIGNALS = {
	[4] = "SIGILL",
	[5] = "SIGTRAP",
	[6] = "SIGABRT",
	[7] = "SIGBUS",
	[8] = "SIGFPE",
	[11] = "SIGSEGV",
}

---@class crash.Entry
---@field pid integer
---@field time integer Microseconds since the epoch
---@field sig integer
---@field exe string
---@field corefile string "present" when the dump is still on disk

--- Recent dumps, newest first.
---@param opts? { mine?: boolean } mine restricts to binaries under $HOME
---@return crash.Entry[]
function M.list(opts)
	opts = opts or {}
	local res = vim.system({ "coredumpctl", "list", "--json=short", "--no-pager" }, { text = true }):wait()
	if res.code ~= 0 then
		return {}
	end
	local ok, entries = pcall(vim.json.decode, res.stdout or "")
	if not ok or type(entries) ~= "table" then
		return {}
	end

	local home = vim.uv.os_homedir()
	local out = {}
	for _, entry in ipairs(entries) do
		local keep = entry.corefile == "present"
		if keep and opts.mine then
			keep = type(entry.exe) == "string" and entry.exe:sub(1, #home) == home
		end
		if keep then
			table.insert(out, entry)
		end
	end

	table.sort(out, function(a, b)
		return (a.time or 0) > (b.time or 0)
	end)
	return out
end

--- One line describing a dump, for the picker.
---@param entry crash.Entry
---@return string
function M.describe(entry)
	return ("%s  %-8s %-6d %s"):format(
		os.date("%Y-%m-%d %H:%M", math.floor((entry.time or 0) / 1e6)),
		SIGNALS[entry.sig] or ("sig " .. tostring(entry.sig)),
		entry.pid or 0,
		vim.fn.fnamemodify(entry.exe or "?", ":~")
	)
end

--- Picks a dump and opens its report.
---@param opts? { mine?: boolean }
function M.pick(opts)
	opts = opts or {}
	if vim.fn.executable("coredumpctl") == 0 then
		Snacks.notify.warn("coredumpctl is not available", { title = "Crash" })
		return
	end

	local entries = M.list(opts)
	if #entries == 0 then
		Snacks.notify.info(
			opts.mine ~= false and "No core dumps from your own binaries" or "No core dumps with a stored corefile",
			{ title = "Crash" }
		)
		return
	end

	vim.ui.select(entries, {
		prompt = "Crash dump",
		format_item = M.describe,
	}, function(entry)
		if entry then
			report.open(entry)
		end
	end)
end

--- Registers the commands and keymaps.
function M.setup()
	vim.api.nvim_create_user_command("Crashes", function(args)
		-- Bang widens the list to every captured dump, not only your own binaries.
		M.pick({ mine = not args.bang })
	end, { bang = true, desc = "Pick a recent core dump (! for all users' binaries)" })

	vim.api.nvim_create_user_command("CrashOpen", function(args)
		require("features.crash.report").open_file(args.fargs[1], args.fargs[2])
	end, {
		nargs = "+",
		complete = "file",
		desc = "Inspect a core file: :CrashOpen <core> [executable]",
	})

	vim.api.nvim_create_user_command("CrashDecode", function(args)
		require("features.crash.kernel").decode({ vmlinux = args.fargs[1], modules_dir = args.fargs[2] })
	end, {
		nargs = "*",
		complete = "file",
		desc = "Symbolise a kernel oops in this buffer: :CrashDecode [vmlinux] [modules_dir]",
	})

	-- <leader>d is the debug group; a crash is a debug session that already happened.
	vim.keymap.set("n", "<leader>dc", function()
		M.pick({ mine = true })
	end, { desc = "Crash dumps" })
	vim.keymap.set("n", "<leader>dC", function()
		M.pick({ mine = false })
	end, { desc = "Crash dumps (all)" })
end

return M
