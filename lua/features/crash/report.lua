--- The crash report buffer: metadata, a symbolised backtrace, and frames you can jump
--- to.
---
--- `coredumpctl info` alone gives frames like `deref (crash + 0x11cc)` — a symbol and
--- an offset, which tells you nothing you can act on. gdb turns the same frame into
--- `deref (s=0x0) at crash.c:7`, which names both the faulting line and the argument
--- that caused it. So gdb does the symbolising and this module does the navigation.
---@class crash.report
local M = {}

local ns = vim.api.nvim_create_namespace("crash_report")

---@class crash.Frame
---@field index integer
---@field func string
---@field file string
---@field lnum integer

--- Parses gdb's backtrace into jumpable frames.
---
--- Matched on structure — `#N … at file:line` — not on the characters a name may use:
--- Go's `main.get`, Zig's `main.main` and Rust's `poke<{closure_env#0}, !>` all broke a
--- name pattern. gdb repeats frame #0 right after "Program terminated"; the repeat is
--- dropped so the fault is marked once.
---@param lines string[]
---@return table<integer, crash.Frame> by display row
function M.parse_frames(lines)
	local frames, seen = {}, {}
	for row, line in ipairs(lines) do
		local index, rest = line:match("^#(%d+)%s+(.*)$")
		local head, file, lnum
		if rest then
			head, file, lnum = rest:match("^(.-)%s+at%s+(%S+):(%d+)%s*$")
		end
		if head and not seen[line] then
			seen[line] = true
			local func = head:gsub("^0x%x+%s+in%s+", ""):gsub("%s*%b()%s*$", "")
			frames[row] = { index = tonumber(index), func = func, file = file, lnum = tonumber(lnum) }
		end
	end
	return frames
end

--- True for frames in the runtime or libc rather than the program.
---@param path string
---@return boolean
local function is_system(path)
	return path:match("^/usr/") ~= nil
		or path:match("^/rustc/") ~= nil
		or path:find("/library/std/", 1, true) ~= nil
		or path:find("/library/core/", 1, true) ~= nil
end

--- Finds a source file named in a backtrace.
---
--- gdb is asked for absolute paths, so this is mostly a check that the file still
--- exists. Older reports and moved trees fall back to the executable's directory.
---@param file string
---@param exe_dir string
---@return string? path
local function resolve(file, exe_dir)
	if vim.uv.fs_stat(file) then
		return file
	end
	for _, path in ipairs({ vim.fs.joinpath(exe_dir, file), vim.fs.joinpath(exe_dir, vim.fs.basename(file)) }) do
		if vim.uv.fs_stat(path) then
			return path
		end
	end
	local found = vim.fs.find(vim.fs.basename(file), { path = exe_dir, type = "file", limit = 2 })
	-- Two files with that name: guessing would open the wrong one.
	return #found == 1 and found[1] or nil
end

--- The row the report should open on: the first frame in the program's own code, else
--- the first frame with a location. Frame 0 of an abort() is inside libc.
---@param frames table<integer, crash.Frame>
---@param exe_dir string
---@return integer? row, integer? fault_row
function M.landing(frames, exe_dir)
	local rows = vim.tbl_keys(frames)
	table.sort(rows)
	local own, fault
	for _, row in ipairs(rows) do
		local frame = frames[row]
		if not fault or frame.index < frames[fault].index then
			fault = row
		end
		local path = resolve(frame.file, exe_dir)
		if not own and path and not is_system(path) then
			own = row
		end
	end
	return own or rows[1], fault
end

--- The buffer called `name`, matched exactly. `vim.fn.bufnr()` treats the name as a
--- pattern, so `crash://core` found `crash://core.1234`.
---@param name string
---@return integer?
local function buffer_named(name)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(buf) == name then
			return buf
		end
	end
	return nil
end

--- A window the source can open in: never the report, never a pinned view.
---@param report_win integer
---@return integer
local function source_window(report_win)
	local candidates = { vim.fn.win_getid(vim.fn.winnr("#")), require("features.workspace").current_editor() }
	for _, win in ipairs(candidates) do
		if
			win
			and win ~= 0
			and win ~= report_win
			and vim.api.nvim_win_is_valid(win)
			and not vim.wo[win].winfixbuf
			and vim.api.nvim_win_get_config(win).relative == ""
		then
			return win
		end
	end
	local win =
		vim.api.nvim_open_win(vim.api.nvim_win_get_buf(report_win), false, { split = "above", win = report_win })
	vim.wo[win].winfixbuf = false
	return win
end

--- Opens the report in a split with frame navigation bound.
---@param title string
---@param lines string[]
---@param exe_dir string
---@param on_debug? fun() Hooked to `D`, for dropping into an interactive debugger
local function show(title, lines, exe_dir, on_debug)
	local name = "crash://" .. title

	-- Reuse the buffer of the same name rather than naming a new one after it:
	-- `nvim_buf_set_name` on a second one fails with E95.
	local buf = buffer_named(name)
	if not buf then
		buf = vim.api.nvim_create_buf(false, true)
		pcall(vim.api.nvim_buf_set_name, buf, name)
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].filetype = "crash"

	-- Already on screen: focus it. A second window on the same report is what made
	-- `<CR>` land in the first one and fail on winfixbuf.
	local win = vim.fn.win_findbuf(buf)[1]
	if win then
		vim.api.nvim_set_current_win(win)
	else
		-- nvim_open_win, not `:split`: the command form fires a layout pass that edgy runs
		-- inside a textlock, and the buffer swap after it fails with E788.
		win = vim.api.nvim_open_win(buf, true, {
			split = "below",
			win = 0,
			height = math.min(#lines + 2, math.floor(vim.o.lines * 0.45)),
		})
	end
	vim.wo[win].number = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].cursorline = true
	vim.wo[win].winfixbuf = true
	vim.wo[win].winhighlight =
		"Normal:LangOutput,NormalFloat:LangOutput,WinBar:LangOutputTitle,WinBarNC:LangOutputTitleNC"
	vim.b[buf].lang_output = true

	local frames = M.parse_frames(lines)
	local landing, fault = M.landing(frames, exe_dir)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for row in pairs(frames) do
		vim.api.nvim_buf_set_extmark(buf, ns, row - 1, 0, {
			line_hl_group = row == fault and "CrashFaultFrame" or "CrashFrame",
			virt_text = { { "  ⏎ jump", "Comment" } },
			virt_text_pos = "eol",
		})
	end

	--- Jumps to the source of the frame under the cursor.
	local function jump()
		local frame = frames[vim.api.nvim_win_get_cursor(0)[1]]
		if not frame then
			Snacks.notify.info("No source frame on this line", { title = "Crash" })
			return
		end
		local path = resolve(frame.file, exe_dir)
		if not path then
			Snacks.notify.warn(("Cannot find %s on disk"):format(frame.file), { title = "Crash" })
			return
		end
		vim.api.nvim_set_current_win(source_window(win))
		vim.cmd.edit(vim.fn.fnameescape(path))
		pcall(vim.api.nvim_win_set_cursor, 0, { frame.lnum, 0 })
		vim.cmd("normal! zz")
	end

	vim.keymap.set("n", "<CR>", jump, { buffer = buf, nowait = true, desc = "Jump to frame" })
	vim.keymap.set("n", "gf", jump, { buffer = buf, nowait = true, desc = "Jump to frame" })
	vim.keymap.set("n", "q", function()
		for _, w in ipairs(vim.fn.win_findbuf(buf)) do
			pcall(vim.api.nvim_win_close, w, true)
		end
	end, { buffer = buf, nowait = true, desc = "Close" })
	if on_debug then
		vim.keymap.set("n", "D", on_debug, { buffer = buf, nowait = true, desc = "Open in gdb" })
	end

	if landing then
		pcall(vim.api.nvim_win_set_cursor, win, { landing, 0 })
	end
end

--- gdb's batch commands.
---
--- Absolute file names, because a relative `null.c` resolves against nothing useful.
--- `bt full` carries the locals, which is usually where the answer is — but only the
--- innermost frames and the outermost few: a runaway recursion is 75,000 frames and
--- seven seconds of gdb otherwise.
---@type string[]
local GDB_COMMANDS = {
	"set filename-display absolute",
	"bt full 48",
	"bt -12",
	"info registers rip rsp rbp",
	"info threads",
}

---@return string
local function gdb_arguments()
	local parts = { "-batch" }
	for _, command in ipairs(GDB_COMMANDS) do
		table.insert(parts, ("-ex '%s'"):format(command))
	end
	return table.concat(parts, " ")
end

--- A banner when gdb says the binary is not the one that crashed. Its frames then
--- point at plausible but wrong lines, which is worse than no lines.
---@param lines string[]
---@return string[]
local function mismatch_banner(lines)
	for _, line in ipairs(lines) do
		if line:find("build%-id") or line:find("No such file") or line:find("Can't open") then
			return { "⚠ The executable changed or is missing since the crash; locations may be wrong.", "" }
		end
	end
	return {}
end

--- Opens the report for a systemd-captured dump.
---@param entry crash.Entry
function M.open(entry)
	local exe = entry.exe or "?"
	local exe_dir = vim.fn.fnamemodify(exe, ":h")
	local title = ("%s.%d"):format(vim.fn.fnamemodify(exe, ":t"), entry.pid or 0)

	Snacks.notify.info("Symbolising with gdb…", { title = "Crash" })

	local header = {
		("Crash: %s"):format(exe),
		("PID %d, signal %d, %s"):format(
			entry.pid or 0,
			entry.sig or 0,
			os.date("%Y-%m-%d %H:%M:%S", math.floor((entry.time or 0) / 1e6))
		),
		"",
	}

	if vim.fn.executable("gdb") == 0 then
		-- Without gdb the frames have no file:line, so nothing is jumpable, but the
		-- symbol names are still worth reading.
		local res = vim.system({ "coredumpctl", "info", tostring(entry.pid) }, { text = true }):wait()
		local lines = vim.list_extend(vim.deepcopy(header), vim.split(res.stdout or "", "\n", { plain = true }))
		table.insert(lines, 2, "gdb is not installed; frames have no source locations")
		show(title, lines, exe_dir)
		return
	end

	vim.system({
		"coredumpctl",
		"debug",
		tostring(entry.pid),
		"--debugger=gdb",
		"--debugger-arguments=" .. gdb_arguments(),
	}, { text = true }, function(res)
		vim.schedule(function()
			local out = M.clean(vim.split(res.stdout or "", "\n", { plain = true }))
			local err = M.clean(vim.split(res.stderr or "", "\n", { plain = true }))
			local lines =
				vim.list_extend(vim.deepcopy(header), mismatch_banner(vim.list_extend(vim.deepcopy(out), err)))
			vim.list_extend(lines, out)
			if #vim.tbl_filter(function(l)
				return vim.trim(l) ~= ""
			end, err) > 0 then
				vim.list_extend(lines, { "", "── stderr ──" })
				vim.list_extend(lines, err)
			end
			show(title, lines, exe_dir, function()
				-- Interactive gdb, for when reading is not enough.
				require("features.lang.output").terminal({
					"coredumpctl",
					"debug",
					tostring(entry.pid),
					"--debugger=gdb",
				}, exe_dir, { title = "gdb " .. title })
			end)
		end)
	end)
end

--- The executable a core file was produced by, from the core itself.
---@param core string
---@return string?
function M.core_executable(core)
	if vim.fn.executable("eu-unstrip") == 0 then
		return nil
	end
	local res = vim.system({ "eu-unstrip", "-n", "--core=" .. core }, { text = true }):wait()
	for _, line in ipairs(vim.split(res.stdout or "", "\n", { trimempty = true })) do
		local path = line:match("%s(/%S+)$")
		if path and vim.uv.fs_stat(path) then
			return path
		end
	end
	return nil
end

--- Inspects a core file directly, for dumps systemd did not capture.
---@param core string
---@param exe? string Defaults to the path recorded inside the core
function M.open_file(core, exe)
	core = vim.fn.expand(core)
	if not vim.uv.fs_stat(core) then
		Snacks.notify.error("No such core file: " .. core, { title = "Crash" })
		return
	end
	if vim.fn.executable("gdb") == 0 then
		Snacks.notify.error("gdb is required to read a core file", { title = "Crash" })
		return
	end

	exe = exe and vim.fn.expand(exe) or M.core_executable(core)
	local cmd = { "gdb", "-batch" }
	for _, command in ipairs(GDB_COMMANDS) do
		vim.list_extend(cmd, { "-ex", command })
	end
	if exe then
		table.insert(cmd, exe)
	end
	table.insert(cmd, "--core=" .. core)

	local exe_dir = exe and vim.fn.fnamemodify(exe, ":h") or vim.fn.getcwd()
	vim.system(cmd, { text = true }, function(res)
		vim.schedule(function()
			local lines = M.clean(vim.split((res.stdout or "") .. "\n" .. (res.stderr or ""), "\n", { plain = true }))
			if not exe then
				table.insert(
					lines,
					1,
					"No executable found for this core; frames have no symbols. :CrashOpen <core> <exe>"
				)
			end
			show(vim.fn.fnamemodify(core, ":t"), vim.list_extend(mismatch_banner(lines), lines), exe_dir)
		end)
	end)
end

--- Drops gdb's startup chatter, which is a third of the output and none of the answer.
--- Warnings that say the symbols are wrong are kept.
---@param lines string[]
---@return string[]
function M.clean(lines)
	local noise = {
		"^This GDB supports auto%-downloading",
		"^%s*<https?://",
		"^Enable debuginfod",
		"^Debuginfod has been disabled",
		"^To make this setting permanent",
		"^%[Thread debugging using",
		"^Using host libthread_db",
		"^%[New LWP",
	}
	local out = {}
	for _, line in ipairs(lines) do
		local drop = line:match("^warning: ")
			and not (line:find("build%-id") or line:find("No such file") or line:find("Can't open"))
		for _, pattern in ipairs(noise) do
			drop = drop or line:match(pattern) ~= nil
		end
		if not drop then
			table.insert(out, line)
		end
	end

	-- Collapse the blank runs left behind.
	local squeezed = {}
	for _, line in ipairs(out) do
		if not (vim.trim(line) == "" and vim.trim(squeezed[#squeezed] or "x") == "") then
			table.insert(squeezed, line)
		end
	end
	return squeezed
end

return M
