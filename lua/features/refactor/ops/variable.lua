--- Extract and inline variable, driven by the locals model rather than a server.
---
--- Both directions need the same two facts — where a binding is visible, and which
--- occurrences belong to it — which is exactly what `locals.scm` provides. That is
--- why these work in every language this config ships a locals query for, with or
--- without a language server running.
---@class refactor.ops.variable
local M = {}

local syntax = require("features.refactor.syntax")
local locals = require("features.refactor.locals")
local Plan = require("features.refactor.plan")

--- How a binding is written, per language. Anything absent falls back to `name = expr`.
---@type table<string, fun(name: string, expr: string): string>
local BINDING = {
	lua = function(name, expr)
		return ("local %s = %s"):format(name, expr)
	end,
	rust = function(name, expr)
		return ("let %s = %s;"):format(name, expr)
	end,
	go = function(name, expr)
		return ("%s := %s"):format(name, expr)
	end,
	zig = function(name, expr)
		return ("const %s = %s;"):format(name, expr)
	end,
	javascript = function(name, expr)
		return ("const %s = %s;"):format(name, expr)
	end,
	typescript = function(name, expr)
		return ("const %s = %s;"):format(name, expr)
	end,
	c = function(name, expr)
		return ("auto %s = %s;"):format(name, expr)
	end,
	python = function(name, expr)
		return ("%s = %s"):format(name, expr)
	end,
}

--- The visual selection as a range, or nil outside visual mode.
---@return integer?, integer?, integer?, integer?
local function selection()
	local from, to = vim.fn.getpos("'<"), vim.fn.getpos("'>")
	if from[2] == 0 or to[2] == 0 then
		return nil
	end
	local line = vim.api.nvim_buf_get_lines(0, to[2] - 1, to[2], false)[1] or ""
	return from[2] - 1, from[3] - 1, to[2] - 1, math.min(to[3], #line)
end

--- Introduces a binding for the selected expression and replaces the selection with it.
---@param opts? { name?: string, preview?: boolean }
function M.extract(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_get_current_buf()
	local srow, scol, erow, ecol = selection()
	if not srow then
		Snacks.notify.warn("Select the expression to extract first", { title = "Refactor" })
		return
	end

	local expr = table.concat(vim.api.nvim_buf_get_text(bufnr, srow, scol, erow, ecol, {}), "\n")
	if vim.trim(expr) == "" then
		Snacks.notify.warn("Selection is empty", { title = "Refactor" })
		return
	end

	local proceed = function(name)
		if not name or vim.trim(name) == "" then
			return
		end
		name = vim.trim(name)

		local plan = Plan.new("Extract variable " .. name)

		if not locals.available(bufnr) then
			plan:skipped_check("collision detection", "no locals query for " .. vim.bo[bufnr].filetype)
		elseif locals.collides(bufnr, name, srow, scol) then
			plan:note("conflict", bufnr, srow, scol, ("`%s` is already in scope here"):format(name))
		end

		-- One edit spanning the whole affected region, not an insert plus a replace on
		-- the same line: two edits sharing a line are applied in an order that can eat
		-- the leading indentation.
		local first = vim.api.nvim_buf_get_lines(bufnr, srow, srow + 1, false)[1] or ""
		local last = vim.api.nvim_buf_get_lines(bufnr, erow, erow + 1, false)[1] or ""
		local indent = first:match("^%s*") or ""
		local build = BINDING[vim.bo[bufnr].filetype] or function(n, e)
			return ("%s = %s"):format(n, e)
		end

		-- The binding goes on its own line above, indented to match the statement the
		-- expression was lifted out of; what is left keeps everything around it.
		local replaced = indent .. build(name, expr) .. "\n" .. first:sub(1, scol) .. name .. last:sub(ecol + 1)
		plan:edit(bufnr, {
			range = { start = { line = srow, character = 0 }, ["end"] = { line = erow, character = #last } },
			newText = replaced,
		})

		Plan.finish(plan, opts)
	end

	if opts.name then
		proceed(opts.name)
	else
		vim.ui.input({ prompt = "Variable name: " }, proceed)
	end
end

--- Replaces every reference to the variable under the cursor with its value, and
--- deletes the binding.
---@param opts? { preview?: boolean }
function M.inline(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_get_current_buf()
	local node = vim.treesitter.get_node()
	if not node then
		Snacks.notify.warn("No node under the cursor", { title = "Refactor" })
		return
	end

	local name = syntax.text(node, bufnr)
	local model = locals.query(bufnr)
	if not model then
		Snacks.notify.warn("No locals query for this language", { title = "Refactor" })
		return
	end

	--- The binding: a definition of this name whose scope contains the cursor.
	local row, col = node:start()
	local def = locals.collides(bufnr, name, row, col)
	if not def then
		Snacks.notify.warn(("`%s` is not a local binding here"):format(name), { title = "Refactor" })
		return
	end

	-- The statement holding the binding is what gets deleted, and its right-hand side
	-- is what gets pasted in its place.
	--
	-- Matched by substring rather than an exact list: grammars spell this node
	-- `variable_declaration`, `local_declaration`, `lexical_declaration`,
	-- `assignment_statement`, `VarDecl`. Lua patterns have no alternation, so this is
	-- three plain `find`s and not one pattern.
	---@param node TSNode
	---@return boolean
	local function is_binding_statement(node)
		local kind = node:type()
		return kind:find("declaration", 1, true) ~= nil or kind:find("statement", 1, true) ~= nil or kind == "VarDecl"
	end

	local statement = def.node
	while statement and not is_binding_statement(statement) do
		local parent = statement:parent()
		if not parent or parent:type() == "chunk" or parent:type() == "block" then
			break
		end
		statement = parent
	end
	if not statement or not is_binding_statement(statement) then
		Snacks.notify.warn("Cannot find the binding statement", { title = "Refactor" })
		return
	end

	local text = statement and syntax.text(statement, bufnr) or ""
	local value = text:match("=%s*(.+)$")
	if not value then
		Snacks.notify.warn("Cannot read the value of this binding", { title = "Refactor" })
		return
	end
	value = vim.trim(value):gsub(";$", "")

	local plan = Plan.new("Inline " .. name)
	local refs = locals.references(bufnr, name, def.scope)
	if #refs == 0 then
		plan:note("skip", bufnr, row, col, "no references; only the binding is removed")
	end
	for _, ref in ipairs(refs) do
		plan:edit(bufnr, syntax.replace(ref, value))
	end

	local dsrow, _, derow = statement:range()
	plan:edit(bufnr, {
		range = { start = { line = dsrow, character = 0 }, ["end"] = { line = derow + 1, character = 0 } },
		newText = "",
	})

	Plan.finish(plan, opts)
end

return M
