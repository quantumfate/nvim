--- Lua: LuaJIT's bytecode listing, and luacheck.
---
--- The thinnest of the four, honestly so. Lua has no build step and no assembly, but
--- it does have a bytecode listing, which is the same question — what does this
--- actually execute — one level up.
---@class lang.lua
local M = {}

--- Titles this adapter renders under, so the keymap can ask whether a view is
--- already on screen. Declared beside the code that uses them: a central table
--- drifts the moment an adapter gains a capability.
---@type table<string, string>
M.titles = {
	assembly = "lua bytecode",
	check = "luacheck",
	build = "lua syntax",
}

local output = require("features.lang.output")
local root = require("lib.root")

--- The interpreter to use: LuaJIT when present, since it is what Neovim embeds.
---@return string
local function interpreter()
	return vim.fn.executable("luajit") == 1 and "luajit" or "lua"
end

---@param buf integer
function M.run(buf)
	output.terminal(
		{ interpreter(), vim.api.nvim_buf_get_name(buf) },
		root.get({ buf = buf }),
		{ title = interpreter() }
	)
end

---@param buf integer
function M.test(buf)
	local dir = root.get({ buf = buf })
	if vim.fn.executable("busted") == 1 then
		output.terminal({ "busted" }, dir, { title = "busted" })
	else
		output.terminal({ "just", "test" }, dir, { title = "just test" })
	end
end

---@param buf integer
function M.check(buf)
	if not output.require_exe("luacheck") then
		return
	end
	output.run({
		cmd = { "luacheck", "--formatter", "plain", vim.api.nvim_buf_get_name(buf) },
		title = M.titles.check,
		cwd = root.get({ buf = buf }),
		filetype = "qf",
	})
end

--- Syntax check without running, via the interpreter's own parser.
---@param buf integer
function M.build(buf)
	output.run({
		cmd = { interpreter(), "-bl", vim.api.nvim_buf_get_name(buf), "/dev/null" },
		title = M.titles.build,
		cwd = root.get({ buf = buf }),
		on_lines = function(lines)
			if #lines == 1 and lines[1] == "" then
				return { "Compiles cleanly." }
			end
			return lines
		end,
	})
end

--- LuaJIT's bytecode listing: Lua's nearest equivalent to reading the assembly.
---@param buf integer
function M.assembly(buf)
	if vim.fn.executable("luajit") == 0 then
		Snacks.notify.warn("luajit is not installed; no bytecode listing available", { title = "Lua" })
		return
	end
	output.run({
		cmd = { "luajit", "-bl", vim.api.nvim_buf_get_name(buf) },
		title = M.titles.assembly,
		cwd = root.get({ buf = buf }),
	})
end

--- The treesitter tree, which is what this config's own tooling reads.
---@param buf integer
function M.tree(buf)
	vim.cmd("InspectTree")
end

---@param buf integer
function M.build_file(buf)
	local dir = root.get({ buf = buf })
	for _, name in ipairs({ "justfile", ".luarc.json", "rockspec" }) do
		local path = vim.fs.joinpath(dir, name)
		if vim.uv.fs_stat(path) then
			vim.cmd.edit(path)
			return
		end
	end
	Snacks.notify.warn("No project file found in " .. dir, { title = "Lua" })
end

return M
