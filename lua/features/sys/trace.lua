--- Every system call the program made, and the source line that made it.
---
--- strace `-k` records the user stack of each call. The frame inside the project's
--- binary is turned into a file and line by addr2line, so a failing `openat` is one
--- `<CR>` away from the `open()` that caused it, and every failure is in quickfix.
---@class sys.trace
local M = {}

M.title = "strace"

local util = require("features.sys.util")

---@class sys.Frame2
---@field object string Binary or library path
---@field symbol string e.g. "main+0x2c", may be empty
---@field addr string Hex offset, no 0x

---@class sys.Call
---@field line string
---@field syscall? string
---@field error? string errno name when the call failed
---@field frames sys.Frame2[]

--- Parses `strace -k` output into calls with their stacks.
---@param lines string[]
---@return sys.Call[]
function M.parse(lines)
	local calls = {}
	for _, line in ipairs(lines) do
		local object, symbol, addr = line:match("^ > (.-)%((.-)%) %[0x(%x+)%]$")
		if object then
			if calls[#calls] then
				table.insert(calls[#calls].frames, { object = object, symbol = symbol, addr = addr })
			end
		elseif line ~= "" then
			local body = line:gsub("^%d+%s+", ""):gsub("^%d+:%d+:%d+%.%d+%s+", "")
			table.insert(calls, {
				line = body,
				syscall = body:match("^([%w_]+)%("),
				error = body:match("= %-1 (E%u+)"),
				frames = {},
			})
		end
	end
	return calls
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

--- Source locations for frames, in one addr2line run.
---@param bin string
---@param frames sys.Frame2[]
---@return { filename: string, lnum: integer }?[]
local function locate(bin, frames)
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

--- Straces the project's binary.
---@param buf integer
function M.run(buf)
	if not require("features.lang.output").require_exe("strace") then
		return
	end
	local output = require("features.lang.output")
	local root = require("lib.root").get({ buf = buf })
	require("features.sys.util").binary(buf, function(bin)
		local log = output.tempfile(".strace")
		util.chain(M.title, { { cmd = { "strace", "-f", "-tt", "-T", "-k", "-o", log, bin }, cwd = root } }, function()
			local ok, lines = pcall(vim.fn.readfile, log)
			pcall(vim.fn.delete, log)
			if not ok then
				Snacks.notify.error("strace wrote no log", { title = "strace" })
				return
			end
			local calls = M.parse(lines)

			-- Locate every failed call's own frame in one go.
			local own, wanted = {}, {}
			for i, call in ipairs(calls) do
				local frame = call.error and M.own_frame(call, bin)
				if frame then
					own[i] = #wanted + 1
					table.insert(wanted, frame)
				end
			end
			local located = locate(bin, wanted)

			local failed, items = 0, {}
			local rows = { ("%s — %d calls"):format(vim.fs.basename(bin), #calls), "" }
			local row_call = {}
			for i, call in ipairs(calls) do
				table.insert(rows, call.line)
				row_call[#rows] = call
				if call.error then
					failed = failed + 1
					local loc = own[i] and located[own[i]]
					if loc then
						table.insert(items, { filename = loc.filename, lnum = loc.lnum, text = call.line })
					end
				end
			end
			rows[1] = rows[1] .. (", %d failed, %d of them from your code"):format(failed, #items)

			local view = output.show({ title = M.title, lines = rows, filetype = "strace", source = buf, link = false })
			local ns = vim.api.nvim_create_namespace("sys_trace")
			for row, call in pairs(row_call) do
				if call.error then
					vim.api.nvim_buf_set_extmark(view.buf, ns, row - 1, 0, { line_hl_group = "DiagnosticVirtualTextError" })
				end
			end
			vim.keymap.set("n", "<CR>", function()
				local call = row_call[vim.api.nvim_win_get_cursor(0)[1]]
				local frame = call and M.own_frame(call, bin)
				local loc = frame and locate(bin, { frame })[1]
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

			vim.fn.setqflist({}, " ", { title = "strace: failed calls", items = items })
		end)
	end)
end

return M
