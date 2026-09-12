--- Every system call the program made, and the source line that made it.
---
--- strace `-k` records the user stack of each call. The frame inside the project's
--- binary is turned into a file and line by addr2line, so a failing `openat` is one
--- `<CR>` away from the `open()` that caused it, and every failure is in quickfix.
---@class sys.trace
local M = {}

M.title = "strace"
M.summary_title = "strace -c"

local util = require("features.sys.util")

---@class sys.Frame2
---@field object string Binary or library path
---@field symbol string e.g. "main+0x2c", may be empty
---@field addr string Hex offset, no 0x

---@class sys.Call
---@field line string
---@field pid? integer Only present with `-f`
---@field syscall? string
---@field error? string errno name when the call failed
---@field status? boolean An exit or signal line rather than a call
---@field frames sys.Frame2[]

--- strace's own syscall classes, in the order the picker offers them.
M.classes = { "all", "file", "network", "memory", "process", "signal", "ipc" }

--- The `-e` arguments for a class; nothing for "all".
---@param class? string
---@return string[]
function M.class_args(class)
	if not class or class == "all" then
		return {}
	end
	return { "-e", "trace=%" .. class }
end

--- Parses `strace -k` output into calls with their stacks.
---
--- With `-f`, threads interleave: a call is split into `<unfinished ...>` and a later
--- `<... name resumed>`. The halves are joined per pid, so a call is one row with its
--- result, and the failure check sees the `= -1` that only the second half carries.
---@param lines string[]
---@return sys.Call[]
function M.parse(lines)
	local calls, pending = {}, {}
	local last
	for _, line in ipairs(lines) do
		local object, symbol, addr = line:match("^ > (.-)%((.-)%) %[0x(%x+)%]$")
		if object then
			if last then
				table.insert(last.frames, { object = object, symbol = symbol, addr = addr })
			end
		elseif line ~= "" then
			-- Without -f there is no pid column; `15:28:10.3` cannot match `%d+%s`.
			local pid, rest = line:match("^(%d+)%s+(.*)$")
			local body = (rest or line):gsub("^%d+:%d+:%d+%.%d+%s+", "")
			local resumed, tail = body:match("^<%.%.%. ([%w_]+) resumed>(.*)$")
			local open = pid and pending[pid]
			if resumed and open and open.syscall == resumed then
				pending[pid] = nil
				open.line = open.line .. tail
				open.error = open.line:match("= %-1 (E%u+)")
				last = open
			else
				local head = body:match("^(.-) <unfinished %.%.%.>$")
				local call = {
					line = head or body,
					pid = tonumber(pid),
					syscall = resumed or body:match("^([%w_]+)%("),
					error = body:match("= %-1 (E%u+)"),
					-- `+++ exited with 0 +++` and `--- SIGSEGV ---` are worth seeing and are
					-- not calls: counting them makes every trace report one call too many.
					status = body:match("^%+%+%+") ~= nil or body:match("^%-%-%-") ~= nil,
					frames = {},
				}
				if head and pid then
					pending[pid] = call
				end
				table.insert(calls, call)
				last = call
			end
		end
	end
	return calls
end

--- Calls grouped by pid in the order each thread first appeared.
---@param calls sys.Call[]
---@return { pid?: integer, calls: sys.Call[], made: integer, failed: integer }[]
function M.group(calls)
	local groups, index = {}, {}
	for _, call in ipairs(calls) do
		local key = call.pid or "-"
		if not index[key] then
			table.insert(groups, { pid = call.pid, calls = {}, made = 0, failed = 0 })
			index[key] = groups[#groups]
		end
		local g = index[key]
		table.insert(g.calls, call)
		if not call.status then
			g.made = g.made + 1
		end
		if call.error then
			g.failed = g.failed + 1
		end
	end
	return groups
end

--- The log's rows: a header per thread when there is more than one, so a worker's
--- calls read as one block instead of interleaved with main's.
---@param calls sys.Call[]
---@param name string Binary name for the title row
---@return string[] rows, table<integer, sys.Call> row_call
function M.render(calls, name)
	local made, failed = 0, 0
	for _, call in ipairs(calls) do
		made = made + (call.status and 0 or 1)
		failed = failed + (call.error and 1 or 0)
	end
	local rows = { ("%s — %d calls, %d failed"):format(name, made, failed) }
	local row_call = {}
	local groups = M.group(calls)
	for i, g in ipairs(groups) do
		table.insert(rows, "")
		if #groups > 1 then
			-- The first pid is the one strace started; the rest are its threads or children.
			table.insert(
				rows,
				("pid %d%s · %d calls, %d failed"):format(g.pid or 0, i == 1 and " (main)" or "", g.made, g.failed)
			)
		end
		for _, call in ipairs(g.calls) do
			table.insert(rows, (#groups > 1 and "  " or "") .. call.line)
			row_call[#rows] = call
		end
	end
	return rows, row_call
end

--- The first frame of a call that lies in `bin`, the program rather than libc.
---@param call sys.Call
---@param bin string
---@return sys.Frame2?
function M.own_frame(call, bin)
	local real = vim.uv.fs_realpath(bin) or bin
	for _, frame in ipairs(call.frames) do
		if frame.object == bin or frame.object == real then
			return frame
		end
	end
	return nil
end

--- Source locations for addresses in `bin`, in one addr2line run.
---@param bin string
---@param frames { addr: string }[] Hex, no 0x
---@return ({ filename: string, lnum: integer }|false)[]
function M.locate(bin, frames)
	if #frames == 0 then
		return {}
	end
	local cmd = { "addr2line", "-e", bin }
	for _, frame in ipairs(frames) do
		table.insert(cmd, "0x" .. frame.addr)
	end
	local res = vim.system(cmd, { text = true }):wait()
	local out = {}
	local i = 0
	for _, line in ipairs(vim.split(res.stdout or "", "\n", { trimempty = true })) do
		i = i + 1
		local file, lnum = line:match("^(%S+):(%d+)")
		out[i] = (file and file ~= "??") and { filename = file, lnum = tonumber(lnum) } or false
	end
	return out
end

---@class sys.SyscallCost
---@field pct number
---@field seconds number
---@field calls integer
---@field errors integer
---@field syscall string

--- Parses the `strace -c` table. The errors column is blank rather than 0 when a
--- syscall never failed, so it is optional in the pattern.
---@param lines string[]
---@return sys.SyscallCost[] rows, sys.SyscallCost? total
function M.parse_summary(lines)
	local rows, total = {}, nil
	for _, line in ipairs(lines) do
		local pct, seconds, calls, errors, name =
			line:match("^%s*([%d%.]+)%s+([%d%.]+)%s+%d+%s+(%d+)%s+(%d*)%s*([%w_]+)%s*$")
		if pct then
			local row = {
				pct = tonumber(pct),
				seconds = tonumber(seconds),
				calls = tonumber(calls),
				errors = tonumber(errors) or 0,
				syscall = name,
			}
			if name == "total" then
				total = row
			else
				table.insert(rows, row)
			end
		end
	end
	return rows, total
end

--- A strace invocation's title suffix for a class filter.
---@param class? string
---@return string
local function label(class)
	return (class and class ~= "all") and (" %" .. class) or ""
end

--- Offers the class filters and re-runs `again` with the choice.
---@param again fun(class: string)
local function pick_class(again)
	vim.ui.select(M.classes, { prompt = "Trace which syscalls?" }, function(choice)
		if choice then
			again(choice)
		end
	end)
end

--- Time per syscall and failures, from `strace -c`.
---@param buf integer
---@param opts? { class?: string, bin?: string }
function M.summary(buf, opts)
	opts = opts or {}
	local output = require("features.lang.output")
	if not output.require_exe("strace") then
		return
	end
	local root = require("lib.root").get({ buf = buf })
	local function go(bin)
		local log = output.tempfile(".strace")
		local cmd = vim.list_extend({ "strace", "-f", "-c", "-o", log }, M.class_args(opts.class))
		table.insert(cmd, bin)
		-- C locale: strace -c prints seconds with the locale's decimal comma otherwise.
		local env = vim.tbl_extend("force", vim.fn.environ(), { LC_ALL = "C" })
		util.chain(M.summary_title, { { cmd = cmd, cwd = root, env = env } }, function()
			local ok, lines = pcall(vim.fn.readfile, log)
			pcall(vim.fn.delete, log)
			local rows, total = M.parse_summary(ok and lines or {})
			if #rows == 0 then
				Snacks.notify.error("strace -c wrote no table", { title = "strace" })
				return
			end
			local out = {
				("%s%s — %d calls, %d errors, %.6fs in syscalls"):format(
					vim.fs.basename(bin),
					label(opts.class),
					total and total.calls or 0,
					total and total.errors or 0,
					total and total.seconds or 0
				),
				"",
				("%6s  %10s  %8s  %7s  %s"):format("time%", "seconds", "calls", "errors", "syscall"),
			}
			local failing = {}
			for _, r in ipairs(rows) do
				table.insert(
					out,
					("%6.2f  %10.6f  %8d  %7s  %s"):format(
						r.pct,
						r.seconds,
						r.calls,
						r.errors > 0 and r.errors or "",
						r.syscall
					)
				)
				failing[#out] = r.errors > 0
			end
			local view = output.show({ title = M.summary_title, lines = out, source = buf, link = false })
			local ns = vim.api.nvim_create_namespace("sys_trace")
			for row, bad in pairs(failing) do
				if bad then
					vim.api.nvim_buf_set_extmark(
						view.buf,
						ns,
						row - 1,
						0,
						{ line_hl_group = "DiagnosticVirtualTextError" }
					)
				end
			end
			vim.keymap.set("n", "F", function()
				pick_class(function(class)
					M.summary(buf, { class = class, bin = bin })
				end)
			end, { buffer = view.buf, nowait = true, desc = "Filter by syscall class" })
			vim.keymap.set("n", "L", function()
				M.run(buf, { class = opts.class, bin = bin })
			end, { buffer = view.buf, nowait = true, desc = "Full log" })
		end)
	end
	if opts.bin then
		go(opts.bin)
	else
		util.binary(buf, go)
	end
end

--- Straces the project's binary.
---@param buf integer
---@param opts? { class?: string, bin?: string }
function M.run(buf, opts)
	opts = opts or {}
	if not require("features.lang.output").require_exe("strace") then
		return
	end
	local output = require("features.lang.output")
	local root = require("lib.root").get({ buf = buf })
	local function go(bin)
		local log = output.tempfile(".strace")
		local cmd = vim.list_extend({ "strace", "-f", "-tt", "-T", "-k", "-o", log }, M.class_args(opts.class))
		table.insert(cmd, bin)
		util.chain(M.title, { { cmd = cmd, cwd = root } }, function()
			local ok, lines = pcall(vim.fn.readfile, log)
			pcall(vim.fn.delete, log)
			if not ok then
				Snacks.notify.error("strace wrote no log", { title = "strace" })
				return
			end
			local calls = M.parse(lines)

			-- Locate every failed call's own frame in one go.
			local own, wanted = {}, {}
			for _, call in ipairs(calls) do
				local frame = call.error and M.own_frame(call, bin)
				if frame then
					own[call] = #wanted + 1
					table.insert(wanted, frame)
				end
			end
			local located = M.locate(bin, wanted)

			local rows, row_call = M.render(calls, vim.fs.basename(bin) .. label(opts.class))
			local items = {}
			for _, call in ipairs(calls) do
				local loc = own[call] and located[own[call]]
				if loc then
					table.insert(items, { filename = loc.filename, lnum = loc.lnum, text = call.line })
				end
			end
			rows[1] = rows[1] .. (", %d of them from your code · S summary · F filter"):format(#items)

			local view = output.show({ title = M.title, lines = rows, filetype = "strace", source = buf, link = false })
			local ns = vim.api.nvim_create_namespace("sys_trace")
			for row, call in pairs(row_call) do
				if call.error then
					vim.api.nvim_buf_set_extmark(
						view.buf,
						ns,
						row - 1,
						0,
						{ line_hl_group = "DiagnosticVirtualTextError" }
					)
				end
			end
			if view.win and vim.api.nvim_win_is_valid(view.win) then
				-- One fold per thread header; open, so the fold is there to close, not to hunt.
				local wo = vim.wo[view.win][0]
				wo.foldmethod = "expr"
				wo.foldexpr = "getline(v:lnum)=~'^pid '?'>1':'='"
				wo.foldlevel = 99
				wo.foldenable = true
			end
			vim.keymap.set("n", "<CR>", function()
				local call = row_call[vim.api.nvim_win_get_cursor(0)[1]]
				local frame = call and M.own_frame(call, bin)
				local loc = frame and M.locate(bin, { frame })[1]
				if not loc then
					Snacks.notify.warn("No frame in " .. vim.fs.basename(bin) .. " for this call", { title = "strace" })
					return
				end
				local editor = require("features.workspace").current_editor()
				if editor then
					vim.api.nvim_set_current_win(editor)
				end
				vim.cmd.edit(vim.fn.fnameescape(loc.filename))
				pcall(vim.api.nvim_win_set_cursor, 0, { loc.lnum, 0 })
			end, { buffer = view.buf, desc = "Jump to the call site" })
			vim.keymap.set("n", "S", function()
				M.summary(buf, { class = opts.class, bin = bin })
			end, { buffer = view.buf, nowait = true, desc = "Time per syscall (strace -c)" })
			vim.keymap.set("n", "F", function()
				pick_class(function(class)
					M.run(buf, { class = class, bin = bin })
				end)
			end, { buffer = view.buf, nowait = true, desc = "Filter by syscall class" })

			vim.fn.setqflist({}, " ", { title = "strace: failed calls", items = items })
		end)
	end
	if opts.bin then
		go(opts.bin)
	else
		util.binary(buf, go)
	end
end

return M
