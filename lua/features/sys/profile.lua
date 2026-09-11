--- Where the time goes, marked on the source lines themselves.
---
--- perf samples the program and attributes each sample to a file and line; the
--- percentages land at the end of those lines in every buffer showing the file, and
--- in quickfix hottest first. The same key again clears them.
---@class sys.profile
local M = {}

M.title = "perf"

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
	require("features.sys.util").binary(buf, function(bin)
		local data = require("features.lang.output").tempfile(".data")
		-- C locale: this machine's locale prints `76,45%`, which is not a number.
		local env = vim.tbl_extend("force", vim.fn.environ(), { LC_ALL = "C" })
		util.chain(M.title, {
			{ cmd = { "perf", "record", "-F", "999", "-o", data, bin }, cwd = root, env = env },
			{
				cmd = { "perf", "report", "-i", data, "--stdio", "--no-children", "-g", "none", "--sort", "srcline", "--percent-limit", "0.5" },
				cwd = root,
				env = env,
			},
		}, function(results)
			pcall(vim.fn.delete, data)
			local last = results[#results]
			if #results < 2 then
				-- perf record failed: usually perf_event_paranoid, and perf says so.
				require("features.lang.output").show({ title = M.title, lines = util.lines(last), mode = "float", source = buf, link = false })
				return
			end
			local hot = M.parse(vim.split(last.stdout or "", "\n", { plain = true }), root)
			if #hot == 0 then
				Snacks.notify.warn("No samples with source lines; build with -g", { title = "perf" })
				return
			end
			M.apply(hot)
			Snacks.notify.info(
				("%s: hottest %s:%d at %s\n<leader>xp again clears · <leader>bR picks another binary"):format(
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

return M
