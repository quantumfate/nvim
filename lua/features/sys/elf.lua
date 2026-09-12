--- The built binary, read directly: its biggest symbols, and any function's machine
--- code with the source line each instruction came from.
---
--- `<leader>va` shows what the compiler emitted for one file. This shows what ended up
--- in the linked program — after inlining across files, LTO and the linker — which is
--- the version that actually runs and the one a crash address points into.
---@class sys.elf
local M = {}

M.titles = { symbols = "elf symbols", disassembly = "elf disassembly" }

local output = require("features.lang.output")
local util = require("features.sys.util")

---@class sys.Symbol
---@field addr integer
---@field size integer
---@field kind string nm type letter
---@field name string Demangled

--- Parses `nm -C -S --defined-only` output.
---@param lines string[]
---@return sys.Symbol[]
function M.parse_nm(lines)
	local out = {}
	for _, line in ipairs(lines) do
		local addr, size, kind, name = line:match("^(%x+) (%x+) (%a) (.+)$")
		if addr then
			table.insert(out, { addr = tonumber(addr, 16), size = tonumber(size, 16), kind = kind, name = name })
		end
	end
	return out
end

--- True when a demangled symbol names the function `name`: `sum`, `crate::sum`,
--- `main.sum`, `main.(*Box).Scale`, with Rust's `::h<hash>` suffix ignored.
---@param symbol string
---@param name string
---@return boolean
function M.names(symbol, name)
	symbol = symbol:gsub("::h%x+$", "")
	return symbol == name or symbol:match("[%.:%)]" .. vim.pesc(name) .. "$") ~= nil
end

--- Narrows symbol matches to the ones worth asking about.
---
--- Aliases at one address are one function (Zig exports `area` and `main.area`). An
--- exact name beats a qualified one, and a plain path beats a trait impl: `report` in
--- a Rust crate should not ask whether you meant `<() as Termination>::report`.
---@param matches sys.Symbol[]
---@param name string
---@return sys.Symbol[]
function M.best_matches(matches, name)
	local by_addr, unique = {}, {}
	for _, s in ipairs(matches) do
		if not by_addr[s.addr] then
			by_addr[s.addr] = true
			table.insert(unique, s)
		end
	end
	local function rank(s)
		local plain = s.name:gsub("::h%x+$", "")
		if plain == name then
			return 3
		end
		return plain:sub(1, 1) == "<" and 1 or 2
	end
	local best, out = 0, {}
	for _, s in ipairs(unique) do
		best = math.max(best, rank(s))
	end
	for _, s in ipairs(unique) do
		if rank(s) == best then
			table.insert(out, s)
		end
	end
	return out
end

--- Turns `objdump -d -l` output into instructions plus a row -> source line map for
--- `file`. The file:line markers are consumed, like `.loc` in the assembly view.
---@param lines string[]
---@param file? string Source path the map should follow
---@return string[] kept, table<integer, integer> map
function M.parse_objdump(lines, file)
	local out, map = {}, {}
	local current, current_file
	local want = file and (vim.uv.fs_realpath(file) or file)
	for _, line in ipairs(lines) do
		local path, lnum = line:match("^(%S+):(%d+)")
		if path and not line:match("^%x+ <") then
			current, current_file = tonumber(lnum), path
		elseif line:match("^%x+ <.+>:$") then
			table.insert(out, line)
		elseif line:match("^%s+%x+:") then
			table.insert(out, line)
			local same = want
				and current_file
				and (
					(vim.uv.fs_realpath(current_file) or current_file) == want
					or vim.fs.basename(current_file) == vim.fs.basename(want)
				)
			if same and current then
				map[#out] = current
			end
		end
		-- Everything else: section banners, `func():` markers, objdump's own warnings.
	end
	return out, map
end

--- Disassembles one symbol of `bin` with source lines.
---@param bin string
---@param symbol sys.Symbol
---@param source integer Buffer to link the cursor to
function M.disassemble(bin, symbol, source)
	local cmd = {
		"objdump",
		"-d",
		"-C",
		"-l",
		"--no-show-raw-insn",
		"-M",
		"intel",
		("--start-address=0x%x"):format(symbol.addr),
		("--stop-address=0x%x"):format(symbol.addr + math.max(symbol.size, 1)),
		bin,
	}
	util.chain(M.titles.disassembly, { { cmd = cmd } }, function(results)
		local res = results[1]
		if res.code ~= 0 then
			output.show({ title = M.titles.disassembly, lines = util.lines(res), source = source, link = false })
			return
		end
		local lines, map = M.parse_objdump(util.lines(res), vim.api.nvim_buf_get_name(source))
		output.show({
			title = M.titles.disassembly,
			lines = lines,
			filetype = "asm",
			source = source,
			map = map,
		})
	end)
end

--- Symbols of `bin`, via nm.
---@param bin string
---@param done fun(symbols: sys.Symbol[])
local function symbols(bin, done)
	vim.system({ "nm", "-C", "-S", "--defined-only", bin }, { text = true }, function(res)
		vim.schedule(function()
			done(M.parse_nm(vim.split(res.stdout or "", "\n", { plain = true })))
		end)
	end)
end

--- Opens `file:line` from addr2line in the editor pane.
---@param bin string
---@param symbol sys.Symbol
local function jump(bin, symbol)
	local res = vim.system({ "addr2line", "-e", bin, "-C", ("0x%x"):format(symbol.addr) }, { text = true }):wait()
	local file, lnum = (res.stdout or ""):match("^(%S+):(%d+)")
	if not file or file == "??" or not vim.uv.fs_stat(file) then
		Snacks.notify.warn("No source line for " .. symbol.name .. " (built without -g?)", { title = "ELF" })
		return
	end
	local editor = require("features.workspace").current_editor()
	if editor then
		vim.api.nvim_set_current_win(editor)
	end
	vim.cmd.edit(vim.fn.fnameescape(file))
	pcall(vim.api.nvim_win_set_cursor, 0, { tonumber(lnum), 0 })
end

--- The biggest symbols of the project's binary. `<CR>` jumps to the source, `d`
--- disassembles.
---@param buf integer
function M.symbols(buf)
	require("features.sys.util").binary(buf, function(bin)
		symbols(bin, function(list)
			-- Sanitizer runtimes add megabytes of their own tables; they would bury the
			-- program's symbols at the top of a size-sorted list.
			list = vim.tbl_filter(function(s)
				return s.size > 0
					and not s.name:match("^__[almtu]?san")
					and not s.name:match("^__sanitizer")
					and not s.name:match("^__interception")
			end, list)
			table.sort(list, function(a, b)
				return a.size > b.size
			end)
			local lines = { ("%s  (%d symbols with a size)"):format(vim.fn.fnamemodify(bin, ":~:."), #list), "" }
			local rows = {}
			for i = 1, math.min(#list, 500) do
				local s = list[i]
				table.insert(lines, ("%10d  %s  %s"):format(s.size, s.kind, s.name))
				rows[#lines] = s
			end
			local view = output.show({ title = M.titles.symbols, lines = lines, source = buf, link = false })
			local function at_cursor()
				return rows[vim.api.nvim_win_get_cursor(0)[1]]
			end
			vim.keymap.set("n", "<CR>", function()
				local s = at_cursor()
				if s then
					jump(bin, s)
				end
			end, { buffer = view.buf, desc = "Jump to source" })
			vim.keymap.set("n", "d", function()
				local s = at_cursor()
				if s then
					M.disassemble(bin, s, buf)
				end
			end, { buffer = view.buf, nowait = true, desc = "Disassemble" })
		end)
	end)
end

--- Disassembles the function under the cursor from the linked binary.
---@param buf integer
function M.function_at_cursor(buf)
	local name = util.function_name(buf)
	if not name then
		Snacks.notify.warn("Cursor is not in a function", { title = "ELF" })
		return
	end
	require("features.sys.util").binary(buf, function(bin)
		symbols(bin, function(list)
			local matches = M.best_matches(
				vim.tbl_filter(function(s)
					return s.size > 0
						and (s.kind == "T" or s.kind == "t" or s.kind == "W" or s.kind == "w")
						and M.names(s.name, name)
				end, list),
				name
			)
			if #matches == 0 then
				local hint = vim.bo[buf].filetype == "go"
						and "\nGo inlines small functions; build with -gcflags=all=-l to keep them"
					or ""
				Snacks.notify.warn(
					("`%s` is not in %s: inlined away, or the binary is stale (rebuild)%s"):format(
						name,
						vim.fs.basename(bin),
						hint
					),
					{ title = "ELF" }
				)
			elseif #matches == 1 then
				M.disassemble(bin, matches[1], buf)
			else
				vim.ui.select(matches, {
					prompt = "Which " .. name .. "?",
					format_item = function(s)
						return ("%s  (%d bytes)"):format(s.name, s.size)
					end,
				}, function(choice)
					if choice then
						M.disassemble(bin, choice, buf)
					end
				end)
			end
		end)
	end)
end

return M
