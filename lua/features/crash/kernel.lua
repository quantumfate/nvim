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

---@class crash.KernelFrame
---@field row integer
---@field symbol string
---@field offset integer
---@field size? integer
---@field module? string `[my_mod]`: the symbol lives in a module, not vmlinux
---@field unreliable boolean `? ` frames are stack scan guesses

--- Frames in a kernel backtrace, as `symbol+offset` pairs.
---@param lines string[]
---@return crash.KernelFrame[]
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
				module = line:match("%[([%w_]+)%]%s*$"),
				unreliable = line:match("%?%s+[%w_%.]+%+0x") ~= nil,
			})
		end
	end
	return out
end

--- `hex + offset` for a 64-bit address, as hex.
---
--- LuaJIT numbers are doubles: `0xffffffff81268ba0 + 0x6d` comes out as `…8800`, and
--- every kernel address is past 2^53. So the arithmetic is done on the two halves.
---@param hex string e.g. "ffffffff81268ba0"
---@param offset integer
---@return string "0x…"
function M.add_offset(hex, offset)
	hex = hex:gsub("^0x", "")
	hex = ("0"):rep(16 - #hex) .. hex
	local hi = tonumber(hex:sub(1, 8), 16)
	local lo = tonumber(hex:sub(9), 16) + offset
	hi = (hi + math.floor(lo / 2 ^ 32)) % 2 ^ 32
	lo = lo % 2 ^ 32
	return ("0x%08x%08x"):format(hi, lo)
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

--- The symbol table of an ELF image, as name -> hex addresses. A list, because static
--- functions repeat: this kernel has 41 `__refcount_add`s.
---@param vmlinux string
---@return table<string, string[]>
local function symbol_table(vmlinux)
	local res = vim.system({ "readelf", "-sW", vmlinux }, { text = true }):wait()
	local out = {}
	for _, line in ipairs(vim.split(res.stdout or "", "\n", { plain = true })) do
		-- Num: Value Size Type Bind Vis Ndx Name
		local value, name = line:match("^%s*%d+:%s+(%x+)%s+%d+%s+FUNC%s+%S+%s+%S+%s+%S+%s+([%w_%.]+)")
		if value and name then
			out[name] = out[name] or {}
			if not vim.tbl_contains(out[name], value) then
				table.insert(out[name], value)
			end
		end
	end
	return out
end

--- True when the image carries DWARF; without it addr2line can only say `??:?`.
---@param vmlinux string
---@return boolean
local function has_debug_info(vmlinux)
	local res = vim.system({ "readelf", "-SW", vmlinux }, { text = true }):wait()
	return (res.stdout or ""):find("%.debug_info") ~= nil
end

--- Parses one line of `addr2line -f -p`: nil when it found nothing.
---@param line string
---@return string?
function M.parse_location(line)
	line = vim.trim(line or "")
	if line == "" or line:match("^%?%?") or line:find("??:", 1, true) then
		return nil
	end
	return line
end

---@param buf integer
---@param ns integer
---@param row integer
---@param text string
---@param group string
local function annotate(buf, ns, row, text, group)
	vim.api.nvim_buf_set_extmark(
		buf,
		ns,
		row - 1,
		0,
		{ virt_text = { { "  " .. text, group } }, virt_text_pos = "eol" }
	)
end

--- Finds a kernel module (.ko) by name.
---@param mod_name string
---@param opts? { modules_dir?: string, modules?: table<string, string> }
---@return string?
function M.find_ko(mod_name, opts)
	opts = opts or {}
	if opts.modules and opts.modules[mod_name] then
		local path = vim.fs.normalize(opts.modules[mod_name])
		if vim.uv.fs_stat(path) then
			return path
		end
	end

	local ko_name = mod_name .. ".ko"

	-- 1. Check user-supplied modules_dir
	if opts.modules_dir then
		local mdir = vim.fn.expand(opts.modules_dir)
		local direct = vim.fs.joinpath(mdir, ko_name)
		if vim.uv.fs_stat(direct) then
			return direct
		end
		local found = vim.fs.find(ko_name, { path = mdir, type = "file", limit = 1 })[1]
		if found and vim.uv.fs_stat(found) then
			return found
		end
	end

	-- 2. Check current working directory / project tree
	local cwd = vim.uv.cwd() or "."
	local found_local = vim.fs.find(ko_name, { path = cwd, type = "file", limit = 1 })[1]
	if found_local and vim.uv.fs_stat(found_local) then
		return found_local
	end

	-- 3. Check /lib/modules/$(uname -r)/ or /usr/lib/modules/$(uname -r)/
	local release = vim.trim(vim.fn.system({ "uname", "-r" }))
	for _, base in ipairs({ "/usr/lib/modules/" .. release, "/lib/modules/" .. release }) do
		if vim.uv.fs_stat(base) then
			local found_sys = vim.fs.find(ko_name, { path = base, type = "file", limit = 1 })[1]
			if found_sys and vim.uv.fs_stat(found_sys) then
				return found_sys
			end
		end
	end

	return nil
end

--- Annotates the kernel trace in the current buffer with source locations.
---@param opts? { vmlinux?: string, modules_dir?: string, modules?: table<string, string> }
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
	if not vim.uv.fs_stat(vmlinux) then
		Snacks.notify.error("No such file: " .. vmlinux, { title = "Kernel" })
		return
	end
	if not has_debug_info(vmlinux) then
		Snacks.notify.warn(
			vmlinux
				.. " has no debug info, so no line can be resolved.\nBuild with CONFIG_DEBUG_INFO, or pass that vmlinux.",
			{ title = "Kernel" }
		)
		return
	end

	local buf = vim.api.nvim_get_current_buf()
	local frames = M.frames(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
	if #frames == 0 then
		Snacks.notify.warn("No `symbol+0xoffset` frames in this buffer", { title = "Kernel" })
		return
	end

	local symbols = symbol_table(vmlinux)
	if vim.tbl_isempty(symbols) then
		Snacks.notify.error("No function symbols in " .. vmlinux .. " (stripped?)", { title = "Kernel" })
		return
	end

	-- Shown as virtual text rather than written in: the buffer is a log, and a log that
	-- has been edited is no longer evidence.
	local ns = vim.api.nvim_create_namespace("crash_kernel")
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	-- Group frames by target binary (vmlinux or module .ko)
	local targets = {}
	local function add_target(path, frame, addr)
		targets[path] = targets[path] or { cmd = { "addr2line", "-e", path, "-f", "-p" }, frames = {} }
		table.insert(targets[path].cmd, addr)
		table.insert(targets[path].frames, frame)
	end

	local symbols_cache = { [vmlinux] = symbols }
	local modules_unresolved, ambiguous = 0, 0

	for _, frame in ipairs(frames) do
		if frame.module then
			local ko = M.find_ko(frame.module, opts)
			if ko and has_debug_info(ko) then
				symbols_cache[ko] = symbols_cache[ko] or symbol_table(ko)
				local mod_syms = symbols_cache[ko]
				local bases = mod_syms[frame.symbol]
				if bases and #bases == 1 then
					add_target(ko, frame, M.add_offset(bases[1], frame.offset))
				elseif bases and #bases > 1 then
					ambiguous = ambiguous + 1
					annotate(
						buf,
						ns,
						frame.row,
						("%d functions named %s in [%s]"):format(#bases, frame.symbol, frame.module),
						"Comment"
					)
				else
					modules_unresolved = modules_unresolved + 1
					annotate(
						buf,
						ns,
						frame.row,
						("symbol %s not found in [%s]"):format(frame.symbol, frame.module),
						"Comment"
					)
				end
			else
				modules_unresolved = modules_unresolved + 1
				annotate(
					buf,
					ns,
					frame.row,
					("in module %s: no .ko with debug info found"):format(frame.module),
					"Comment"
				)
			end
		else
			local bases = symbols[frame.symbol]
			if bases and #bases > 1 then
				ambiguous = ambiguous + 1
				annotate(buf, ns, frame.row, ("%d functions named %s"):format(#bases, frame.symbol), "Comment")
			elseif bases then
				add_target(vmlinux, frame, M.add_offset(bases[1], frame.offset))
			end
		end
	end

	local resolved = 0
	for _, entry in pairs(targets) do
		local res = vim.system(entry.cmd, { text = true }):wait()
		local out = vim.split(res.stdout or "", "\n", { trimempty = true })
		for i, frame in ipairs(entry.frames) do
			local where = M.parse_location(out[i])
			if where then
				resolved = resolved + 1
				local mod_tag = frame.module and (" [" .. frame.module .. "]") or ""
				annotate(
					buf,
					ns,
					frame.row,
					(frame.unreliable and "? " or "") .. where .. mod_tag,
					"DiagnosticVirtualTextWarn"
				)
			end
		end
	end

	local extra = {}
	if modules_unresolved > 0 then
		table.insert(extra, modules_unresolved .. " unresolved in modules")
	end
	if ambiguous > 0 then
		table.insert(extra, ambiguous .. " ambiguous")
	end
	local summary = ("Resolved %d/%d frames%s"):format(
		resolved,
		#frames,
		#extra > 0 and (" (" .. table.concat(extra, ", ") .. ")") or ""
	)
	if resolved == 0 then
		Snacks.notify.warn(summary .. "\nThe vmlinux probably does not match the crashed kernel.", { title = "Kernel" })
	else
		Snacks.notify.info(summary, { title = "Kernel" })
	end
end

return M
