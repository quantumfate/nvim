--- Where the time goes, marked on the source lines themselves.
---
--- perf samples the program and attributes each sample to a file and line; the
--- percentages land at the end of those lines in every buffer showing the file, and
--- in quickfix hottest first. The same key again clears them. The recording is kept,
--- so annotating a function afterwards reads the same run instead of a new one.
---@class sys.profile
local M = {}

M.title = "perf"
M.annotate_title = "perf annotate"
M.flame_title = "perf flame"

local ns = vim.api.nvim_create_namespace("sys_profile")
local util = require("features.sys.util")

---@class sys.HotLine
---@field filename string
---@field lnum integer
---@field pct number
---@field text string

--- The last profile, kept so files opened afterwards get their marks too.
---@type sys.HotLine[]
local current = {}

--- The last recording: annotate reuses it while the binary has not been rebuilt.
---@type { bin: string, data: string }?
local recording = nil

--- C locale: this machine's locale prints `76,45%`, which is not a number.
---@return table<string, string>
local function c_env()
	return vim.tbl_extend("force", vim.fn.environ(), { LC_ALL = "C" })
end

--- Parses `perf report --sort srcline` output. perf prints basenames, so they are
--- resolved against the project.
---@param lines string[]
---@param root? string
---@return sys.HotLine[]
function M.parse(lines, root)
	local stack = require("features.sys.stack")
	local out = {}
	for _, line in ipairs(lines) do
		local pct, file, lnum = line:match("^%s*([%d%.]+)%%%s+(.-):(%d+)%s*$")
		if pct and file ~= "??" and tonumber(lnum) > 0 then
			local path = stack.resolve(file, { root = root, cwd = root })
			table.insert(out, {
				filename = path,
				lnum = tonumber(lnum),
				pct = tonumber(pct),
				text = ("%5.1f%%"):format(tonumber(pct)),
			})
		end
	end
	return out
end

--- Parses `perf report --sort sym` into user-space symbols, hottest first.
---@param lines string[]
---@return { pct: number, name: string }[]
function M.parse_symbols(lines)
	local out = {}
	for _, line in ipairs(lines) do
		local pct, name = line:match("^%s*([%d%.]+)%%%s+%[%.%]%s+(.-)%s*$")
		if pct then
			table.insert(out, { pct = tonumber(pct), name = name })
		end
	end
	return out
end

---@class sys.Instruction
---@field pct number
---@field addr string Hex, no 0x
---@field text string
---@field loc? string perf's own `file:line`, only on sampled instructions

--- Parses `perf annotate --stdio --no-source` into instructions.
---@param lines string[]
---@return sys.Instruction[]
function M.parse_annotate(lines)
	local out = {}
	for _, line in ipairs(lines) do
		local pct, addr, text = line:match("^%s*([%d%.]+)%s*:%s+(%x+):%s+(.-)%s*$")
		if pct then
			local code, loc = text:match("^(.-)%s*// (%S+:%d+)$")
			table.insert(out, { pct = tonumber(pct), addr = addr, text = code or text, loc = loc })
		end
	end
	return out
end

--- The annotate view's rows, the row -> source line map for the cursor link, and
--- each row's heat.
---
--- Locations come from addr2line for every instruction, not from perf's `// file:line`,
--- which is only printed on sampled rows. Lines from other files (an inlined header)
--- are left out of the map so they cannot move the cursor around this buffer.
---@param symbol string
---@param instructions sys.Instruction[]
---@param locations ({ filename: string, lnum: integer }|false)[] Parallel to instructions
---@param source? string Path of the buffer being annotated
---@return string[] rows, table<integer, integer> map, table<integer, number> heat
function M.annotate_rows(symbol, instructions, locations, source)
	local want = source and vim.fs.basename(source)
	local rows = { ("%s — %d instructions · <CR> to source"):format(symbol, #instructions), "" }
	local map, heat = {}, {}
	for i, ins in ipairs(instructions) do
		local loc = locations[i]
		local where = loc and ("%s:%d"):format(vim.fs.basename(loc.filename), loc.lnum) or ""
		table.insert(
			rows,
			("%7s  %6s  %-44s %s"):format(ins.pct > 0 and ("%.2f%%"):format(ins.pct) or "", ins.addr, ins.text, where)
		)
		if loc and (not want or vim.fs.basename(loc.filename) == want) then
			map[#rows] = loc.lnum
		end
		if ins.pct > 0 then
			heat[#rows] = ins.pct
		end
	end
	return rows, map, heat
end

--- Folds `perf script` samples into flamegraph's `root;...;leaf count` lines.
---
--- Weighted by period, not by sample count: perf's first samples of each thread carry
--- a period of 1 while it calibrates the frequency, and counting them equally makes
--- the dynamic loader look as expensive as the hot loop.
---@param lines string[]
---@return string[] folded Sorted by stack
function M.fold(lines)
	local totals = {}
	local comm, period, frames

	local function flush()
		if comm and #frames > 0 then
			local stack = { comm }
			for i = #frames, 1, -1 do
				table.insert(stack, frames[i])
			end
			local key = table.concat(stack, ";")
			totals[key] = (totals[key] or 0) + period
		end
		comm = nil
	end

	for _, line in ipairs(lines) do
		local c, p = line:match("^(%S.-)%s+%d+[/%d]*%s+[%d%.]+:%s+(%d+)%s+%S+:%s*$")
		if c then
			flush()
			comm, period, frames = c, tonumber(p), {}
		elseif comm and line:match("^%s*$") then
			flush()
		elseif comm then
			local sym, dso = line:match("^%s+%x+%s+(.-)%s+%((.*)%)%s*$")
			if sym then
				sym = sym:gsub("%+0x%x+$", "")
				if sym == "[unknown]" and dso ~= "[unknown]" then
					sym = "[" .. vim.fs.basename(dso) .. "]"
				end
				table.insert(frames, sym)
			end
		end
	end
	flush()

	local out = {}
	for stack, count in pairs(totals) do
		table.insert(out, ("%s %d"):format(stack, count))
	end
	table.sort(out)
	return out
end

---@param pct number
---@return string
local function group(pct)
	return pct >= 20 and "DiagnosticError" or pct >= 5 and "DiagnosticWarn" or "DiagnosticHint"
end

--- Marks the lines of `buf` that appear in the current profile.
---@param buf integer
local function mark(buf)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	local name = vim.api.nvim_buf_get_name(buf)
	local real = vim.uv.fs_realpath(name) or name
	for _, hot in ipairs(current) do
		if hot.filename == name or hot.filename == real then
			pcall(vim.api.nvim_buf_set_extmark, buf, ns, hot.lnum - 1, 0, {
				virt_text = { { "  ▮ " .. vim.trim(hot.text), group(hot.pct) } },
				virt_text_pos = "eol",
			})
		end
	end
end

--- Shows a profile: marks in every loaded buffer and a quickfix list, hottest first.
---@param hot sys.HotLine[]
function M.apply(hot)
	current = hot
	table.sort(current, function(a, b)
		return a.pct > b.pct
	end)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			mark(buf)
		end
	end
	local group_id = vim.api.nvim_create_augroup("sys_profile", { clear = true })
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = group_id,
		callback = function(args)
			mark(args.buf)
		end,
	})
	vim.fn.setqflist({}, " ", { title = "perf: hot lines", items = current })
end

--- Removes every mark and forgets the profile.
function M.clear()
	current = {}
	pcall(vim.api.nvim_del_augroup_by_name, "sys_profile")
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		end
	end
end

---@return boolean
function M.active()
	return #current > 0
end

--- Remembers a recording, deleting the one it replaces.
---@param bin string
---@param data string
local function remember(bin, data)
	if recording and recording.data ~= data then
		pcall(vim.fn.delete, recording.data)
	end
	recording = { bin = bin, data = data }
end

--- The kept recording of `bin`, when it is newer than the binary.
---@param bin string
---@return string?
local function fresh_recording(bin)
	if not recording or recording.bin ~= bin then
		return nil
	end
	local data, exe = vim.uv.fs_stat(recording.data), vim.uv.fs_stat(bin)
	if data and exe and data.mtime.sec >= exe.mtime.sec then
		return recording.data
	end
	return nil
end

--- Profiles the project's binary, or clears the marks when a profile is showing.
---@param buf integer
function M.run(buf)
	if M.active() then
		M.clear()
		return
	end
	if not require("features.lang.output").require_exe("perf") then
		return
	end
	local root = require("lib.root").get({ buf = buf })
	util.binary(buf, function(bin)
		local data = require("features.lang.output").tempfile(".data")
		local env = c_env()
		util.chain(M.title, {
			{ cmd = { "perf", "record", "-F", "999", "-o", data, bin }, cwd = root, env = env },
			{
				cmd = {
					"perf",
					"report",
					"-i",
					data,
					"--stdio",
					"--no-children",
					"-g",
					"none",
					"--sort",
					"srcline",
					"--percent-limit",
					"0.5",
				},
				cwd = root,
				env = env,
			},
		}, function(results)
			local last = results[#results]
			if #results < 2 then
				pcall(vim.fn.delete, data)
				-- perf record failed: usually perf_event_paranoid, and perf says so.
				require("features.lang.output").show({
					title = M.title,
					lines = util.lines(last),
					mode = "float",
					source = buf,
					link = false,
				})
				return
			end
			remember(bin, data)
			local hot = M.parse(vim.split(last.stdout or "", "\n", { plain = true }), root)
			if #hot == 0 then
				Snacks.notify.warn("No samples with source lines; build with -g", { title = "perf" })
				return
			end
			M.apply(hot)
			Snacks.notify.info(
				("%s: hottest %s:%d at %s\n<leader>xp again clears · <leader>xf annotates a function · <leader>bR picks another binary"):format(
					vim.fs.basename(bin),
					vim.fs.basename(hot[1].filename),
					hot[1].lnum,
					vim.trim(hot[1].text)
				),
				{ title = "perf" }
			)
		end)
	end)
end

--- Calls `with` on a recording of `bin`: the kept one, or a new one.
---@param bin string
---@param root string
---@param buf integer
---@param with fun(data: string)
local function with_recording(bin, root, buf, with)
	local data = fresh_recording(bin)
	if data then
		with(data)
		return
	end
	data = require("features.lang.output").tempfile(".data")
	util.chain(
		M.annotate_title,
		{ { cmd = { "perf", "record", "-F", "999", "-o", data, bin }, cwd = root, env = c_env() } },
		function(results)
			if results[1].code ~= 0 then
				pcall(vim.fn.delete, data)
				require("features.lang.output").show({
					title = M.annotate_title,
					lines = util.lines(results[1]),
					mode = "float",
					source = buf,
					link = false,
				})
				return
			end
			remember(bin, data)
			with(data)
		end
	)
end

--- Annotates `symbol` from `data` into the view.
---@param buf integer
---@param bin string
---@param data string
---@param symbol string
---@param root string
local function annotate_symbol(buf, bin, data, symbol, root)
	local output = require("features.lang.output")
	util.chain(M.annotate_title, {
		{ cmd = { "perf", "annotate", "-i", data, "--stdio", "--no-source", symbol }, cwd = root, env = c_env() },
	}, function(results)
		local instructions = M.parse_annotate(vim.split(results[1].stdout or "", "\n", { plain = true }))
		if #instructions == 0 then
			output.show({
				title = M.annotate_title,
				lines = util.lines(results[1]),
				mode = "float",
				source = buf,
				link = false,
			})
			return
		end
		local locations = require("features.sys.trace").locate(bin, instructions)
		local rows, map, heat = M.annotate_rows(symbol, instructions, locations, vim.api.nvim_buf_get_name(buf))
		local view = output.show({
			title = M.annotate_title,
			lines = rows,
			filetype = "asm",
			mode = "split",
			source = buf,
			map = map,
		})
		local hl = vim.api.nvim_create_namespace("sys_profile_annotate")
		vim.api.nvim_buf_clear_namespace(view.buf, hl, 0, -1)
		local hottest, top = nil, 0
		for row, pct in pairs(heat) do
			vim.api.nvim_buf_set_extmark(view.buf, hl, row - 1, 0, { end_col = 7, hl_group = group(pct) })
			if pct >= 20 then
				vim.api.nvim_buf_set_extmark(view.buf, hl, row - 1, 0, { line_hl_group = "DiagnosticVirtualTextError" })
			end
			if pct > top then
				hottest, top = row, pct
			end
		end
		if hottest and view.win and vim.api.nvim_win_is_valid(view.win) then
			pcall(vim.api.nvim_win_set_cursor, view.win, { hottest, 0 })
		end
	end)
end

--- Per-instruction percentages for the function under the cursor, from the kept
--- profile of this binary or a new one.
---@param buf integer
function M.annotate(buf)
	if not require("features.lang.output").require_exe("perf", "addr2line") then
		return
	end
	local name = util.function_name(buf)
	if not name then
		Snacks.notify.warn("Cursor is not in a function", { title = "perf" })
		return
	end
	local root = require("lib.root").get({ buf = buf })
	util.binary(buf, function(bin)
		with_recording(bin, root, buf, function(data)
			util.chain(M.annotate_title, {
				{
					cmd = { "perf", "report", "-i", data, "--stdio", "--no-children", "-g", "none", "--sort", "sym" },
					cwd = root,
					env = c_env(),
				},
			}, function(results)
				local elf = require("features.sys.elf")
				-- Mangled Rust and Go names still match the bare name under the cursor.
				local matches = vim.tbl_filter(function(s)
					return elf.names(s.name, name)
				end, M.parse_symbols(vim.split(results[1].stdout or "", "\n", { plain = true })))
				if #matches == 0 then
					Snacks.notify.warn(
						("`%s` has no samples in this profile of %s: not hot, or inlined into its caller"):format(
							name,
							vim.fs.basename(bin)
						),
						{ title = "perf" }
					)
					return
				end
				annotate_symbol(buf, bin, data, matches[1].name, root)
			end)
		end)
	end)
end

--- Where folded stacks and SVGs go: outside the project, named after the binary.
---@param bin string
---@return string
function M.flame_path(bin)
	local dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "sys-flame")
	vim.fn.mkdir(dir, "p")
	return vim.fs.joinpath(dir, vim.fs.basename(bin))
end

--- Records with DWARF call graphs, folds the stacks and renders an SVG when a
--- flamegraph renderer is installed.
---
--- DWARF rather than frame pointers: most distro libraries and `-O2` builds omit
--- them, and a frame-pointer walk through those stops at the first libc frame.
---@param buf integer
---@param opts? { on_done?: fun(folded: string, svg?: string) }
function M.flame(buf, opts)
	opts = opts or {}
	if not require("features.lang.output").require_exe("perf") then
		return
	end
	local root = require("lib.root").get({ buf = buf })
	util.binary(buf, function(bin)
		local data = require("features.lang.output").tempfile(".data")
		local env = c_env()
		util.chain(M.flame_title, {
			{
				cmd = { "perf", "record", "-F", "499", "--call-graph", "dwarf", "-o", data, bin },
				cwd = root,
				env = env,
			},
			{ cmd = { "perf", "script", "-i", data }, cwd = root, env = env },
		}, function(results)
			pcall(vim.fn.delete, data)
			local last = results[#results]
			if #results < 2 or last.code ~= 0 then
				require("features.lang.output").show({
					title = M.flame_title,
					lines = util.lines(last),
					mode = "float",
					source = buf,
					link = false,
				})
				return
			end
			local folded = M.fold(vim.split(last.stdout or "", "\n", { plain = true }))
			local base = M.flame_path(bin)
			vim.fn.writefile(folded, base .. ".folded")
			local renderer = vim.fn.executable("inferno-flamegraph") == 1 and "inferno-flamegraph"
				or vim.fn.executable("flamegraph.pl") == 1 and "flamegraph.pl"
				or nil
			if not renderer then
				Snacks.notify.info(
					("%d stacks folded to %s.folded\nNo inferno-flamegraph or flamegraph.pl to render it"):format(
						#folded,
						base
					),
					{ title = "perf" }
				)
				if opts.on_done then
					opts.on_done(base .. ".folded")
				end
				return
			end
			vim.system({ renderer, base .. ".folded" }, { text = true }, function(res)
				vim.schedule(function()
					if res.code ~= 0 then
						Snacks.notify.error(renderer .. " failed:\n" .. (res.stderr or ""), { title = "perf" })
						return
					end
					vim.fn.writefile(vim.split(res.stdout or "", "\n", { plain = true }), base .. ".svg")
					Snacks.notify.info(("Flamegraph: %s.svg"):format(base), { title = "perf" })
					vim.ui.open(base .. ".svg")
					if opts.on_done then
						opts.on_done(base .. ".folded", base .. ".svg")
					end
				end)
			end)
		end)
	end)
end

return M
