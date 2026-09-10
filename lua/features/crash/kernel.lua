--- Symbolising a kernel oops.
---
--- A panic or oops arrives as text — from `dmesg`, a journal entry, a serial console,
--- or a photograph of a screen. The frames name a symbol and an offset:
---
---     [<ffffffff81234567>] my_driver_probe+0x47/0x120
---
--- The symbol tells you the function, the offset tells you where inside it, and
--- neither tells you the line. `addr2line` against the matching `vmlinux` does, which
--- is the difference between "somewhere in probe" and a cursor on the statement.
---
--- The kernel ships `scripts/decode_stacktrace.sh` for this; it needs the build tree.
--- This does the same job from whatever the buffer happens to contain.
---@class crash.kernel
local M = {}

--- Frames in a kernel backtrace, as `symbol+offset` pairs.
---@param lines string[]
---@return { row: integer, symbol: string, offset: integer, size: integer? }[]
function M.frames(lines)
	local out = {}
	for row, line in ipairs(lines) do
		-- `symbol+0x47/0x120`, with or without a leading address and module suffix.
		local symbol, offset, size = line:match("([%w_%.]+)%+0x(%x+)/0x(%x+)")
		if not symbol then
			symbol, offset = line:match("([%w_%.]+)%+0x(%x+)")
		end
		if symbol then
			table.insert(out, {
				row = row,
				symbol = symbol,
				offset = tonumber(offset, 16),
				size = size and tonumber(size, 16) or nil,
			})
		end
	end
	return out
end

--- Guesses where the running kernel's debug image is.
---
--- Distributions disagree, and a kernel developer usually wants the `vmlinux` in the
--- tree they just built rather than the running one.
---@return string?
local function find_vmlinux()
	local release = vim.trim(vim.fn.system({ "uname", "-r" }))
	local candidates = {
		"vmlinux",
		"./vmlinux",
		("/usr/lib/debug/boot/vmlinux-%s"):format(release),
		("/usr/lib/modules/%s/build/vmlinux"):format(release),
		("/lib/modules/%s/build/vmlinux"):format(release),
		("/boot/vmlinux-%s"):format(release),
	}
	for _, path in ipairs(candidates) do
		if vim.uv.fs_stat(path) then
			return path
		end
	end
	return nil
end

--- Resolves one `symbol+offset` to a source location.
---
--- Two steps, because addr2line takes addresses and an oops gives symbols: the symbol
--- table supplies the base address, and the offset is added to it.
---@param vmlinux string
---@param symbols table<string, integer>
---@param frame { symbol: string, offset: integer }
---@return string?
local function locate(vmlinux, symbols, frame)
	local base = symbols[frame.symbol]
	if not base then
		return nil
	end
	local res = vim.system({
		"addr2line",
		"-e",
		vmlinux,
		"-f",
		"-i",
		"-p",
		("0x%x"):format(base + frame.offset),
	}, { text = true }):wait()
	if res.code ~= 0 then
		return nil
	end
	local first = vim.split(vim.trim(res.stdout or ""), "\n", { plain = true })[1]
	return (first and first ~= "" and not first:match("^%?%?")) and first or nil
end

--- The symbol table of an ELF image, as name -> address.
---@param vmlinux string
---@return table<string, integer>
local function symbol_table(vmlinux)
	local res = vim.system({ "readelf", "-sW", vmlinux }, { text = true }):wait()
	local out = {}
	for _, line in ipairs(vim.split(res.stdout or "", "\n", { plain = true })) do
		-- Num: Value Size Type Bind Vis Ndx Name
		local value, name = line:match("^%s*%d+:%s+(%x+)%s+%d+%s+FUNC%s+%S+%s+%S+%s+%S+%s+([%w_%.]+)")
		if value and name then
			out[name] = tonumber(value, 16)
		end
	end
	return out
end

--- Annotates the kernel trace in the current buffer with source locations.
---@param opts? { vmlinux?: string }
function M.decode(opts)
	opts = opts or {}
	if not (vim.fn.executable("addr2line") == 1 and vim.fn.executable("readelf") == 1) then
		Snacks.notify.error("addr2line and readelf are required (binutils)", { title = "Kernel" })
		return
	end

	local vmlinux = opts.vmlinux and vim.fn.expand(opts.vmlinux) or find_vmlinux()
	if not vmlinux then
		Snacks.notify.warn(
			"No vmlinux found.\nPass one: :CrashDecode /path/to/vmlinux\nIt must match the kernel that crashed.",
			{ title = "Kernel" }
		)
		return
	end

	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local frames = M.frames(lines)
	if #frames == 0 then
		Snacks.notify.warn("No `symbol+0xoffset` frames in this buffer", { title = "Kernel" })
		return
	end

	Snacks.notify.info(("Decoding %d frame(s) against %s…"):format(#frames, vim.fn.fnamemodify(vmlinux, ":t")), {
		title = "Kernel",
	})

	local symbols = symbol_table(vmlinux)
	if vim.tbl_isempty(symbols) then
		Snacks.notify.error("No function symbols in " .. vmlinux .. " (stripped?)", { title = "Kernel" })
		return
	end

	-- Shown as virtual text rather than written in: the buffer is a log, and a log that
	-- has been edited is no longer evidence.
	local ns = vim.api.nvim_create_namespace("crash_kernel")
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	local resolved = 0
	for _, frame in ipairs(frames) do
		local where = locate(vmlinux, symbols, frame)
		if where then
			resolved = resolved + 1
			vim.api.nvim_buf_set_extmark(buf, ns, frame.row - 1, 0, {
				virt_text = { { "  " .. where, "DiagnosticVirtualTextWarn" } },
				virt_text_pos = "eol",
			})
		end
	end

	if resolved == 0 then
		Snacks.notify.warn(
			"No frames resolved. The vmlinux probably does not match the crashed kernel.",
			{ title = "Kernel" }
		)
	else
		Snacks.notify.info(("Resolved %d/%d frames"):format(resolved, #frames), { title = "Kernel" })
	end
end

return M
