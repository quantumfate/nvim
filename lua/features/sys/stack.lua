--- Stack traces from any tool, as quickfix entries you can walk.
---
--- ASan, UBSan, TSan, valgrind, gdb, Rust panics, Go panics, Python tracebacks, Node
--- and Zig all print "function at file:line", each in its own dialect. One parser per
--- dialect, one list at the end: `]q` walks a heap overflow the same way it walks a
--- Python traceback.
---@class sys.stack
local M = {}

---@class sys.Frame
---@field filename? string
---@field lnum? integer
---@field col? integer
---@field text string
---@field own? boolean Inside the project, rather than libc or the runtime
---@field valid? integer 0 for a section header with no location

--- Lines that start a section of a report. Kept as unlocated entries so the list
--- reads as the report does: "allocated by thread T0 here:" above its frames.
---@type string[]
local HEADERS = {
	"ERROR: AddressSanitizer",
	"ERROR: LeakSanitizer",
	"WARNING: ThreadSanitizer",
	"allocated by thread",
	"freed by thread",
	"previously allocated by",
	"Previous write",
	"Previous read",
	"Direct leak",
	"Indirect leak",
	"Invalid read",
	"Invalid write",
	"Invalid free",
	"Conditional jump",
	"Traceback %(most recent call last%)",
	"^goroutine %d+ %[",
	"^panic: ",
	"^fatal error: ",
	"^Segmentation fault",
}

--- One matcher per dialect: file, line, column and a label, or nil.
---@type (fun(line: string): string?, string?, string?, string?)[]
local DIALECTS = {
	-- sanitizers: "    #0 0x5561 in sum /src/s.c:10:79"
	function(line)
		local fn, file, l, c = line:match("^%s*#%d+ 0x%x+ in (.-) (%S+):(%d+):(%d+)$")
		if not fn then
			fn, file, l = line:match("^%s*#%d+ 0x%x+ in (.-) (%S+):(%d+)$")
		end
		return file, l, c, fn
	end,
	-- gdb: "#1  0x0000555 in main (argc=1) at s.c:16"
	function(line)
		local fn, file, l = line:match("^#%d+%s+.-([%w_:~<>%.]+) %(.-%) at (%S+):(%d+)$")
		return file, l, nil, fn
	end,
	-- valgrind: "==12==    at 0x10916B: sum (s.c:10)"
	function(line)
		local fn, file, l = line:match("^==%d+==%s+[ab][ty] 0x%x+: (.-) %(([^%s:]+):(%d+)%)$")
		return file, l, nil, fn
	end,
	-- UBSan: "s.c:15:28: runtime error: signed integer overflow"
	function(line)
		local file, l, c, msg = line:match("^(%S+):(%d+):(%d+): runtime error: (.*)$")
		return file, l, c, msg and ("runtime error: " .. msg)
	end,
	-- Rust: "thread 'main' panicked at src/main.rs:4:5:"
	function(line)
		local file, l, c = line:match("panicked at (%S-):(%d+):(%d+)")
		return file, l, c, file and vim.trim(line)
	end,
	-- Node: "    at area (/p/x.js:3:5)"
	function(line)
		local fn, file, l, c = line:match("^%s+at (.-) %((%S+):(%d+):(%d+)%)$")
		return file, l, c, fn
	end,
	-- Rust backtrace and anonymous Node frames: "      at ./src/main.rs:4:5"
	function(line)
		local file, l, c = line:match("^%s+at (%S+):(%d+):(%d+)$")
		return file, l, c, file and ""
	end,
	-- Go: "\t/home/u/p/main.go:12 +0x1d"
	function(line)
		local file, l = line:match("^%s+(%S+%.go):(%d+)")
		return file, l, nil, file and ""
	end,
	-- Python: '  File "/p/x.py", line 3, in f'
	function(line)
		local file, l, fn = line:match('^%s*File "(.-)", line (%d+), in (.*)$')
		return file, l, nil, fn
	end,
	-- Zig: "/p/main.zig:3:5: 0x1034 in main (main)"
	function(line)
		local file, l, c, fn = line:match("^(%S+%.zig):(%d+):(%d+): 0x%x+ in (%S+)")
		return file, l, c, fn
	end,
}

--- A path as printed, made absolute: tools print absolute, cwd-relative and bare
--- basenames (valgrind), and a quickfix entry that does not open is worse than none.
---@param file string
---@param opts { cwd?: string, root?: string }
---@return string
local function resolve(file, opts)
	file = file:gsub("^%./", "")
	if file:sub(1, 1) == "/" then
		return file
	end
	for _, base in ipairs({ opts.cwd, opts.root }) do
		if base and vim.uv.fs_stat(vim.fs.joinpath(base, file)) then
			return vim.fs.joinpath(base, file)
		end
	end
	if opts.root then
		local found = vim.fs.find(vim.fs.basename(file), { path = opts.root, type = "file", limit = 1 })[1]
		if found then
			return found
		end
	end
	return file
end

--- True for frames in the project, as opposed to libc, the Rust std or the Go runtime.
---@param file string
---@param root? string
---@return boolean
local function is_own(file, root)
	if not root or file:sub(1, #root) ~= root then
		return false
	end
	return not (file:find("/.cargo/registry/", 1, true) or file:find("/site-packages/", 1, true))
end

--- Every frame and section header in `lines`, in order.
---@param lines string[]
---@param opts? { cwd?: string, root?: string }
---@return sys.Frame[]
function M.parse(lines, opts)
	opts = opts or {}
	local items = {}
	for _, line in ipairs(lines) do
		local matched = false
		for _, dialect in ipairs(DIALECTS) do
			local file, l, c, label = dialect(line)
			if file and l then
				local path = resolve(file, opts)
				table.insert(items, {
					filename = path,
					lnum = tonumber(l),
					col = tonumber(c) or 1,
					text = label or "",
					own = is_own(path, opts.root),
				})
				matched = true
				break
			end
		end
		if not matched then
			for _, header in ipairs(HEADERS) do
				if line:find(header) then
					table.insert(items, { text = vim.trim(line), valid = 0 })
					break
				end
			end
		end
	end
	return items
end

--- Puts frames in the quickfix list, positioned at the first frame in your code.
---@param items sys.Frame[]
---@param title string
---@return integer located Number of entries with a location
function M.to_quickfix(items, title)
	local located, first_own = 0, nil
	for i, item in ipairs(items) do
		if item.filename then
			located = located + 1
			first_own = first_own or (item.own and i or nil)
		end
	end
	vim.fn.setqflist({}, " ", { title = title, items = items, idx = first_own or 1 })
	return located
end

--- Parses a buffer (a terminal, a pasted report, a log) into the quickfix list and
--- jumps to the first frame in the project.
---@param buf integer
function M.from_buffer(buf)
	local root = require("lib.root").get({ buf = buf })
	local items = M.parse(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { cwd = vim.uv.cwd(), root = root })
	local located = M.to_quickfix(items, "Stack: " .. vim.fn.bufname(buf))
	if located == 0 then
		Snacks.notify.warn("No stack frames recognised in this buffer", { title = "Stack" })
		return
	end
	Snacks.notify.info(("%d frame(s); ]q / [q to walk"):format(located), { title = "Stack" })
	require("features.workspace").dock().open("quickfix")
end

return M
