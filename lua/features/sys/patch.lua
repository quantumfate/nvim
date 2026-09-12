--- Linux kernel patch series workflow with b4: prep, cover letters, trailers,
--- checkpatch across the series, and dry-run reviews before sending.
---@class sys.patch
local M = {}

M.title = "b4 patch"
M.cover_title = "Cover letter"
M.check_title = "b4 check"
M.send_title = "b4 send (dry-run)"
M.trailers_title = "b4 trailers"

local output = require("features.lang.output")

--- Finds the git repository root for `buf`.
---@param buf? integer
---@return string?
function M.git_root(buf)
	local b = (buf and buf ~= 0) and buf or vim.api.nvim_get_current_buf()
	local file = vim.api.nvim_buf_get_name(b)
	local start = file ~= "" and vim.fs.dirname(file) or vim.uv.cwd()
	local dot_git = vim.fs.find(".git", { path = start, upward = true })[1]
	if dot_git then
		return vim.fs.dirname(dot_git)
	end
	return nil
end

--- Parses `b4 prep --show-info` lines into a structured table.
---@param lines string[]
---@return table? info
function M.parse_info(lines)
	local info = { commits = {} }
	local count = 0
	for _, line in ipairs(lines) do
		local key, val = line:match("^([%w%-_]+):%s*(.*)$")
		if key and val then
			count = count + 1
			if key:match("^commit%-") then
				local hash = key:gsub("^commit%-", "")
				table.insert(info.commits, { hash = hash, subject = val })
			else
				local norm_key = key:gsub("%-", "_")
				if val == "True" then
					info[norm_key] = true
				elseif val == "False" then
					info[norm_key] = false
				elseif tonumber(val) then
					info[norm_key] = tonumber(val)
				else
					info[norm_key] = val
				end
			end
		end
	end
	return count > 0 and info or nil
end

--- Gets series info for the git tree at `dir`.
---@param dir string
---@return table? info, string? err
function M.info(dir)
	local res = vim.system({ "b4", "prep", "--show-info" }, { cwd = dir, text = true }):wait()
	if res.code ~= 0 then
		return nil, vim.trim((res.stderr or "") .. "\n" .. (res.stdout or ""))
	end
	local info = M.parse_info(vim.split(res.stdout or "", "\n", { plain = true }))
	if not info then
		return nil, "could not parse b4 series info"
	end
	return info
end

--- Parses `b4 prep --check` output into quickfix items.
---@param lines string[]
---@param dir string
---@return table[] items
function M.parse_check(lines, dir)
	local items = {}
	local cur_commit = nil
	for _, raw_line in ipairs(lines) do
		local line = raw_line:gsub("\x1b%[[%d;]*%a", "")
		local hash = line:match("(%x+):")
		if hash and #hash >= 8 and not line:find("checkpatch%.pl") then
			cur_commit = hash
		end
		local file, lnum, kind, msg = line:match("checkpatch%.pl:%s*([^:%s]+):(%d+):%s*(%u+):%s*(.*)$")
		if not file then
			lnum, kind, msg = line:match("checkpatch%.pl:%s*:(%d+):%s*(%u+):%s*(.*)$")
			file = ""
		end
		if kind and msg then
			local path = (file and file ~= "") and vim.fs.joinpath(dir, file) or dir
			table.insert(items, {
				filename = path,
				lnum = tonumber(lnum) or 1,
				text = (cur_commit and ("[" .. cur_commit:sub(1, 10) .. "] ") or "") .. msg,
				type = kind == "ERROR" and "E" or kind == "WARNING" and "W" or "I",
			})
		end
	end
	return items
end

--- Creates a new series branch or enrolls the current branch.
---@param buf integer
---@param name? string
function M.prep(buf, name)
	local dir = M.git_root(buf)
	if not dir then
		Snacks.notify.warn("Not inside a git repository", { title = M.title })
		return
	end

	local function run_prep(series_name)
		local cmd = series_name ~= "" and { "b4", "prep", "-n", series_name } or { "b4", "prep", "-e" }
		local res = vim.system(cmd, { cwd = dir, text = true }):wait()
		if res.code ~= 0 then
			Snacks.notify.error("b4 prep failed:\n" .. vim.trim(res.stderr or res.stdout or ""), { title = M.title })
		else
			Snacks.notify.info(vim.trim(res.stdout or "b4 prep succeeded"), { title = M.title })
		end
	end

	if name and name ~= "" then
		run_prep(name)
	else
		vim.ui.input({ prompt = "Series name (leave blank to enroll current branch): " }, function(input)
			if input ~= nil then
				run_prep(vim.trim(input))
			end
		end)
	end
end

--- Opens the cover letter in a dedicated buffer for editing.
--- On :write, updates the series cover letter via b4 prep --edit-cover.
---@param buf integer
function M.cover(buf)
	local dir = M.git_root(buf)
	if not dir then
		Snacks.notify.warn("Not inside a git repository", { title = M.title })
		return
	end

	local info, err = M.info(dir)
	if not info or not info.start_commit then
		Snacks.notify.warn(err or "Not on a b4 prep branch. Run b4 prep first.", { title = M.title })
		return
	end

	-- Extract current cover letter text from start-commit
	local res = vim.system({ "git", "log", "-1", "--format=%B", info.start_commit }, { cwd = dir, text = true }):wait()
	if res.code ~= 0 then
		Snacks.notify.error("Could not read cover letter commit: " .. (res.stderr or ""), { title = M.title })
		return
	end

	local lines = vim.split(vim.trim(res.stdout or ""), "\n", { plain = true })
	local cbuf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_lines(cbuf, 0, -1, false, lines)
	vim.bo[cbuf].filetype = "gitcommit"
	vim.bo[cbuf].buftype = "acwrite"
	vim.api.nvim_buf_set_name(cbuf, vim.fs.joinpath(dir, "b4-cover-letter"))

	-- On :write, write buffer to a tempfile and invoke b4 prep --edit-cover with a copy script
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = cbuf,
		callback = function()
			local content = vim.api.nvim_buf_get_lines(cbuf, 0, -1, false)
			local src_temp = vim.fn.tempname()
			vim.fn.writefile(content, src_temp)

			local script_temp = vim.fn.tempname()
			vim.fn.writefile({
				"#!/bin/sh",
				('cp "%s" "$1"'):format(src_temp),
			}, script_temp)
			vim.fn.setfperm(script_temp, "rwxr-xr-x")

			local update_res = vim.system({ "b4", "prep", "--edit-cover" }, {
				cwd = dir,
				env = { EDITOR = script_temp },
				text = true,
			}):wait()

			pcall(vim.fn.delete, src_temp)
			pcall(vim.fn.delete, script_temp)

			if update_res.code == 0 then
				vim.bo[cbuf].modified = false
				Snacks.notify.info("Cover letter updated successfully", { title = M.cover_title })
			else
				Snacks.notify.error(
					"b4 prep --edit-cover failed:\n" .. vim.trim(update_res.stderr or update_res.stdout or ""),
					{ title = M.cover_title }
				)
			end
		end,
	})

	-- Open buffer in horizontal split
	vim.cmd("split")
	vim.api.nvim_win_set_buf(0, cbuf)
end

--- Updates series trailers from lore.kernel.org.
---@param buf integer
function M.trailers(buf)
	local dir = M.git_root(buf)
	if not dir then
		Snacks.notify.warn("Not inside a git repository", { title = M.title })
		return
	end

	Snacks.notify.info("Checking lore.kernel.org for trailers…", { title = M.trailers_title })
	local res = vim.system({ "b4", "trailers", "-u" }, { cwd = dir, text = true }):wait(60000)
	local out = vim.trim((res.stdout or "") .. "\n" .. (res.stderr or ""))
	local lines = vim.split(out, "\n", { plain = true })
	if res.code == 0 then
		output.show({ title = M.trailers_title, lines = lines, mode = "float", source = buf, link = false })
	else
		Snacks.notify.error("b4 trailers -u failed:\n" .. out, { title = M.trailers_title })
	end
end

--- Runs checkpatch over the whole series.
---@param buf integer
function M.check(buf)
	local dir = M.git_root(buf)
	if not dir then
		Snacks.notify.warn("Not inside a git repository", { title = M.title })
		return
	end

	local res = vim.system({ "b4", "prep", "--check" }, { cwd = dir, text = true }):wait(60000)
	local lines = vim.split(vim.trim((res.stdout or "") .. "\n" .. (res.stderr or "")), "\n", { plain = true })
	local items = M.parse_check(lines, dir)

	if #items > 0 then
		vim.fn.setqflist({}, " ", { title = "b4 check (" .. #items .. " issues)", items = items })
		require("features.workspace").dock().open("quickfix")
	else
		output.show({ title = M.check_title, lines = lines, mode = "float", source = buf, link = false })
		if res.code == 0 then
			Snacks.notify.info("b4 prep --check: clean", { title = M.check_title })
		end
	end
end

--- Runs b4 send --dry-run and renders the email messages for review.
---@param buf integer
function M.send_dry_run(buf)
	local dir = M.git_root(buf)
	if not dir then
		Snacks.notify.warn("Not inside a git repository", { title = M.title })
		return
	end

	local res = vim.system({ "b4", "send", "--dry-run" }, { cwd = dir, text = true }):wait(60000)
	local out = vim.trim((res.stdout or "") .. "\n" .. (res.stderr or ""))
	local lines = vim.split(out, "\n", { plain = true })
	output.show({
		title = M.send_title,
		lines = lines,
		filetype = "mail",
		mode = "split",
		source = buf,
		link = false,
	})
end

--- Interactive action picker for b4 patch workflow.
---@param buf integer
function M.pick(buf)
	local actions = {
		{
			label = "prep: create or enroll series branch",
			fn = function()
				M.prep(buf)
			end,
		},
		{
			label = "cover: edit cover letter in buffer",
			fn = function()
				M.cover(buf)
			end,
		},
		{
			label = "check: checkpatch over entire series",
			fn = function()
				M.check(buf)
			end,
		},
		{
			label = "trailers: update reviews & acks from lore (-u)",
			fn = function()
				M.trailers(buf)
			end,
		},
		{
			label = "send: dry-run review before sending",
			fn = function()
				M.send_dry_run(buf)
			end,
		},
		{
			label = "info: show series details",
			fn = function()
				local cwd = vim.uv.cwd() or "."
				local dir = M.git_root(buf) or cwd
				local info, err = M.info(dir)
				if info then
					local lines = vim.split(vim.inspect(info), "\n", { plain = true })
					output.show({
						title = M.title .. " info",
						lines = lines,
						mode = "float",
						source = buf,
						link = false,
					})
				else
					Snacks.notify.warn(err or "No series info available", { title = M.title })
				end
			end,
		},
	}

	vim.ui.select(actions, {
		prompt = "b4 patch workflow",
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if choice then
			choice.fn()
		end
	end)
end

--- Headless JSON representation of series info.
---@param dir string
---@return string json
function M.json(dir)
	local info, err = M.info(dir)
	if not info then
		return vim.json.encode({ error = err or "no b4 series info" })
	end
	return vim.json.encode(info)
end

return M
