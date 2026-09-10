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
--- Matches `#3  0x... in name (args) at file:line` and the leading-frame form that
--- omits the address.
---@param lines string[]
---@return table<integer, crash.Frame> by display row
local function parse_frames(lines)
	local frames = {}
	for row, line in ipairs(lines) do
		local index, func, file, lnum = line:match("^#(%d+)%s+.-in%s+([%w_:~<>]+)%s*%b()%s+at%s+([^:]+):(%d+)")
		if not index then
			index, func, file, lnum = line:match("^#(%d+)%s+([%w_:~<>]+)%s*%b()%s+at%s+([^:]+):(%d+)")
		end
		if index and file then
			frames[row] = {
				index = tonumber(index),
				func = func,
				file = file,
				lnum = tonumber(lnum),
			}
		end
	end
	return frames
end

--- Finds a source file named in a backtrace.
---
--- gdb records the path the binary was compiled with, which is often relative or
--- points at a build directory that no longer exists. So an exact path is tried first,
--- then the same name under the executable's directory, then a search from the project
--- root — which is what makes frames resolvable for a binary built somewhere else.
---@param file string
---@param exe_dir string
---@return string? path
local function resolve(file, exe_dir)
	if vim.uv.fs_stat(file) then
		return file
	end

	local candidates = {
		vim.fs.joinpath(exe_dir, file),
		vim.fs.joinpath(exe_dir, vim.fn.fnamemodify(file, ":t")),
	}
	for _, path in ipairs(candidates) do
		if vim.uv.fs_stat(path) then
			return path
		end
	end

	local found = vim.fs.find(vim.fn.fnamemodify(file, ":t"), {
		path = exe_dir,
		upward = false,
		type = "file",
		limit = 1,
	})[1]
	return found
end

--- Opens the report in a split with frame navigation bound.
---@param title string
---@param lines string[]
---@param exe_dir string
---@param on_debug? fun() Hooked to `D`, for dropping into an interactive debugger
local function show(title, lines, exe_dir, on_debug)
	local name = "crash://" .. title

	-- Reuse the buffer of the same name rather than naming a new one after it. Closing
	-- a report window leaves the buffer alive, and `nvim_buf_set_name` on a second one
	-- fails with `E95: Buffer with this name already exists` — so reopening a crash you
	-- had already looked at was the one case guaranteed to break.
	local buf
	local existing = vim.fn.bufnr(name)
	if existing ~= -1 and vim.api.nvim_buf_is_valid(existing) then
		buf = existing
	else
		buf = vim.api.nvim_create_buf(false, true)
		pcall(vim.api.nvim_buf_set_name, buf, name)
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].filetype = "crash"

	-- nvim_open_win, not `:split`: the command form fires a layout pass that edgy runs
	-- inside a textlock, and the buffer swap after it fails with E788.
	local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.45))
	local win = vim.api.nvim_open_win(buf, true, {
		split = "below",
		win = 0,
		height = height,
	})
	vim.wo[win].number = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].cursorline = true
	vim.wo[win].winfixbuf = true
	vim.wo[win].winhighlight =
		"Normal:LangOutput,NormalFloat:LangOutput,WinBar:LangOutputTitle,WinBarNC:LangOutputTitleNC"
	vim.b[buf].lang_output = true

	local frames = parse_frames(lines)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for row, frame in pairs(frames) do
		-- Frame 0 is where it died; the rest are how it got there.
		vim.api.nvim_buf_set_extmark(buf, ns, row - 1, 0, {
			line_hl_group = frame.index == 0 and "CrashFaultFrame" or "CrashFrame",
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
		vim.cmd.wincmd("p")
		vim.cmd.edit(path)
		pcall(vim.api.nvim_win_set_cursor, 0, { frame.lnum, 0 })
		vim.cmd("normal! zz")
	end

	vim.keymap.set("n", "<CR>", jump, { buffer = buf, nowait = true, desc = "Jump to frame" })
	vim.keymap.set("n", "gf", jump, { buffer = buf, nowait = true, desc = "Jump to frame" })
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, nowait = true, desc = "Close" })
	if on_debug then
		vim.keymap.set("n", "D", on_debug, { buffer = buf, nowait = true, desc = "Open in gdb" })
	end

	-- Land on the faulting frame rather than the header.
	local first = math.huge
	for row in pairs(frames) do
		first = math.min(first, row)
	end
	if first ~= math.huge then
		pcall(vim.api.nvim_win_set_cursor, 0, { first, 0 })
	end
end

--- gdb's batch commands. `bt full` carries the locals, which is usually where the
--- answer is; the registers matter when the trace itself is corrupt.
local GDB_ARGS = "-batch -ex 'bt full' -ex 'info registers rip rsp rbp' -ex 'info threads'"

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
		local lines = vim.list_extend(header, vim.split(res.stdout or "", "\n", { plain = true }))
		table.insert(lines, 2, "gdb is not installed; frames have no source locations")
		show(title, lines, exe_dir)
		return
	end

	vim.system({
		"coredumpctl",
		"debug",
		tostring(entry.pid),
		"--debugger=gdb",
		"--debugger-arguments=" .. GDB_ARGS,
	}, { text = true }, function(res)
		vim.schedule(function()
			local lines = vim.list_extend(header, M.clean(vim.split(res.stdout or "", "\n", { plain = true })))
			if res.code ~= 0 and #lines <= #header then
				lines = vim.list_extend(lines, vim.split(res.stderr or "", "\n", { plain = true }))
			end
			show(title, lines, exe_dir, function()
				-- Interactive gdb, for when reading is not enough. Same framing as every
				-- other output window, so it is visibly not the editor.
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

--- Inspects a core file directly, for dumps systemd did not capture.
---@param core string
---@param exe? string Defaults to the path recorded inside the core
function M.open_file(core, exe)
	core = vim.fn.expand(core)
	if not vim.uv.fs_stat(core) then
		Snacks.notify.error("No such core file: " .. core, { title = "Crash" })
		return
	end
	if not vim.fn.executable("gdb") == 1 then
		Snacks.notify.error("gdb is required to read a core file", { title = "Crash" })
		return
	end

	-- gdb can read a core without the executable, but then it has no symbols at all.
	local cmd = { "gdb", "-batch", "-ex", "bt full", "-ex", "info registers rip rsp rbp" }
	if exe then
		table.insert(cmd, vim.fn.expand(exe))
	end
	table.insert(cmd, "--core=" .. core)

	local exe_dir = exe and vim.fn.fnamemodify(vim.fn.expand(exe), ":h") or vim.fn.getcwd()
	vim.system(cmd, { text = true }, function(res)
		vim.schedule(function()
			local lines = M.clean(vim.split((res.stdout or "") .. "\n" .. (res.stderr or ""), "\n", { plain = true }))
			show(vim.fn.fnamemodify(core, ":t"), lines, exe_dir)
		end)
	end)
end

--- Drops gdb's startup chatter, which is a third of the output and none of the answer.
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
		"^warning: ",
	}
	local out = {}
	for _, line in ipairs(lines) do
		local drop = false
		for _, pattern in ipairs(noise) do
			if line:match(pattern) then
				drop = true
				break
			end
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
