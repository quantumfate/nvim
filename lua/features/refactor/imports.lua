--- Working out how one file refers to a symbol in another.
---
--- Per language, because there is no general answer: Lua resolves a dotted module
--- name against `package.path` and the runtimepath, JS and TS resolve a relative file
--- path. Both are rule-based, which is why they are here; Rust's module tree and C's
--- header/source split are not, and are left reporting a skip instead of guessing.
---@class refactor.imports
local M = {}

local syntax = require("features.refactor.syntax")

---@class refactor.ImportRule
---@field module fun(path: string, from: string): string? How `from` names the file at `path`
---@field statement fun(module: string, name: string): string The line to insert
---@field find fun(bufnr: integer, module: string): boolean Whether it is already imported

--- Dotted module name for a Lua file, from the nearest `lua/` directory down.
--- `~/.config/nvim/lua/features/refactor/plan.lua` is `features.refactor.plan`, which
--- is the same rule the runtimepath uses.
---@param path string
---@return string?
local function lua_module(path)
	local normalized = vim.fs.normalize(path):gsub("%.lua$", "")
	local after = normalized:match("/lua/(.+)$")
	if not after then
		-- Not under a `lua/` directory: a plain script, addressed by basename.
		return vim.fn.fnamemodify(normalized, ":t")
	end
	return (after:gsub("/", ".")):gsub("%.init$", "")
end

--- Relative specifier from one file to another, the way JS and TS resolve them.
---@param path string Target file
---@param from string Importing file
---@return string
local function relative_module(path, from)
	local target = vim.fs.normalize(path):gsub("%.[jt]sx?$", "")
	local dir = vim.fs.normalize(vim.fn.fnamemodify(from, ":h"))

	-- Walk up until the two share a prefix, counting the steps as `../`.
	local up = ""
	while dir ~= "" and dir ~= "/" and target:sub(1, #dir + 1) ~= dir .. "/" do
		dir = vim.fs.dirname(dir)
		up = up .. "../"
	end
	local rest = target:sub(#dir + 2)
	return up == "" and ("./" .. rest) or (up .. rest)
end

---@type table<string, refactor.ImportRule>
local RULES = {
	lua = {
		module = lua_module,
		statement = function(module, name)
			return ('local %s = require("%s")'):format(name, module)
		end,
		find = function(bufnr, module)
			for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
				-- Substring, not a pattern: a module name is full of dots, and the whole
				-- buffer, not just the header — a require inside a function still means the
				-- module is reachable and a second one at the top would be noise.
				if line:find('"' .. module .. '"', 1, true) or line:find("'" .. module .. "'", 1, true) then
					return true
				end
			end
			return false
		end,
	},
}

local js_rule = {
	module = relative_module,
	statement = function(module, name)
		return ('import { %s } from "%s";'):format(name, module)
	end,
	find = function(bufnr, module)
		for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
			-- Substring, not a pattern: a module name is full of dots, and the whole
			-- buffer, not just the header — a require inside a function still means the
			-- module is reachable and a second one at the top would be noise.
			if line:find('"' .. module .. '"', 1, true) or line:find("'" .. module .. "'", 1, true) then
				return true
			end
		end
		return false
	end,
}
for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
	RULES[ft] = js_rule
end

--- True when this config can write imports for the buffer's language.
---@param bufnr integer
---@return boolean
function M.supported(bufnr)
	return RULES[vim.bo[bufnr].filetype] ~= nil
end

--- The import line `bufnr` needs to reach `name` in the file at `path`, or nil when
--- the language is unsupported or the import is already there.
---@param bufnr integer The file that needs the import
---@param path string The file holding the symbol
---@param name string
---@return string? statement, string? module
function M.needed(bufnr, path, name)
	local rule = RULES[vim.bo[bufnr].filetype]
	if not rule then
		return nil
	end
	local module = rule.module(path, vim.api.nvim_buf_get_name(bufnr))
	if not module or rule.find(bufnr, module) then
		return nil
	end
	return rule.statement(module, name), module
end

--- Row to insert an import at.
---
--- After the existing import block when there is one, so the new line joins it.
--- Otherwise after the file's header comment — inserting at row 0 would put the
--- import above the comment that describes the file.
---@param bufnr integer
---@return integer row 0-indexed
function M.insert_row(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 40, false)

	local last_import = nil
	for i, line in ipairs(lines) do
		if line:find("^%s*local%s.*require%(") or line:find("^%s*import%s") or line:find("^%s*const%s.*require%(") then
			last_import = i
		end
	end
	if last_import then
		return last_import
	end

	-- No imports yet: skip the leading comment block and any blank line after it.
	local row = 0
	for i, line in ipairs(lines) do
		local trimmed = vim.trim(line)
		if trimmed ~= "" and not trimmed:match("^%-%-") and not trimmed:match("^//") and not trimmed:match("^/%*") then
			row = i - 1
			break
		end
	end
	return row
end

--- Free identifiers in a range: names it uses but does not itself define. These are
--- what the destination file will need imports for once the code lands there.
---@param bufnr integer
---@param srow integer
---@param erow integer
---@return string[]
function M.free_names(bufnr, srow, erow)
	local locals = require("features.refactor.locals")
	local model = locals.query(bufnr)
	if not model then
		return {}
	end

	local defined = {}
	for _, def in ipairs(model.definitions) do
		local row = def.node:start()
		if row >= srow and row <= erow then
			defined[def.name] = true
		end
	end

	local out, seen = {}, {}
	for _, ref in ipairs(model.references) do
		local row = ref:start()
		if row >= srow and row <= erow then
			local name = syntax.text(ref, bufnr)
			if not defined[name] and not seen[name] then
				seen[name] = true
				table.insert(out, name)
			end
		end
	end
	return out
end

return M
