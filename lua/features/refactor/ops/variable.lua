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

local binding_value, is_member_name, is_written, needs_parens

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
	javascriptreact = function(name, expr)
		return ("const %s = %s;"):format(name, expr)
	end,
	typescriptreact = function(name, expr)
		return ("const %s = %s;"):format(name, expr)
	end,
	cpp = function(name, expr)
		return ("auto %s = %s;"):format(name, expr)
	end,
	c = function(name, expr)
		return ("auto %s = %s;"):format(name, expr)
	end,
	python = function(name, expr)
		return ("%s = %s"):format(name, expr)
	end,
}

--- Node types that hold a binding, which the value search may descend through.
---@param kind string
---@return boolean
local function binding_like(kind)
	return kind:find("assignment") ~= nil
		or kind:find("declaration") ~= nil
		or kind:find("declarator") ~= nil
		or kind:find("spec") ~= nil
		or kind:find("statement") ~= nil
end

--- The value of a binding statement, read by field: `x, y := a, b` and `let (x, y) = t`
--- are refused instead of pasting the whole right-hand side into one name.
---@param statement TSNode
---@param ft string
---@return TSNode? value, string? problem
function binding_value(statement, ft)
	if ft == "zig" and statement:type() == "variable_declaration" then
		return statement:named_child(statement:named_child_count() - 1)
	end
	local queue = { statement }
	while #queue > 0 do
		local node = table.remove(queue, 1)
		local left = node:field("left")[1] or node:field("pattern")[1]
		if
			left
			and (
				left:type():find("tuple")
				or left:type():find("pattern_list")
				or (left:type():find("list") and left:named_child_count() > 1)
			)
		then
			return nil, "binds several names at once"
		end
		local values = #node:field("value") > 0 and node:field("value") or node:field("right")
		if #values > 1 then
			return nil, "binds several values at once"
		end
		local value = values[1]
		if value then
			if value:type():find("list") then
				if value:named_child_count() > 1 then
					return nil, "binds several values at once"
				end
				value = value:named_child(0)
			end
			return value
		end
		for child in node:iter_children() do
			if child:named() and binding_like(child:type()) then
				table.insert(queue, child)
			end
		end
	end
end

--- True for `p.w` / `r.W` / `c.x` / `f(x=...)`: the name of a field, not the variable.
---@param ref TSNode
---@return boolean
function is_member_name(ref)
	local parent = ref:parent()
	if not parent then
		return false
	end
	for _, field in ipairs({ "field", "attribute", "property" }) do
		local member = parent:field(field)[1]
		if member and member:equal(ref) then
			return true
		end
	end
	-- `f(x=...)` in Python, `{ x = 1 }` in Lua: a key, not a use.
	local kind = parent:type()
	local key = (kind == "keyword_argument" or kind == "field") and parent:field("name")[1]
	return key and key:equal(ref) or false
end

--- True when the reference is written to (`x += 1`, `x = y`) or borrowed (`&x`, `&mut x`).
---@param ref TSNode
---@param bufnr integer
---@return boolean
function is_written(ref, bufnr)
	local parent = ref:parent()
	if parent and parent:type():find("list") then
		parent = parent:parent()
	end
	if not parent then
		return false
	end
	local kind = parent:type()
	if kind:find("assignment") or kind:find("update") or kind:find("inc_") or kind:find("dec_") then
		local right = parent:field("right")[1] or parent:field("value")[1]
		if not right then
			return true
		end
		local rr, rc = right:start()
		local r, c = ref:start()
		return r < rr or (r == rr and c < rc)
	end
	return (kind:find("reference") or kind:find("unary")) ~= nil and syntax.text(parent, bufnr):match("^&") ~= nil
end

--- Whether pasting a compound value here needs parentheses to keep its meaning.
---@param ref TSNode
---@return boolean
function needs_parens(ref)
	local parent = ref:parent()
	if not parent then
		return false
	end
	local kind = parent:type()
	return kind:find("binary") ~= nil
		or kind:find("unary") ~= nil
		or kind:find("cast") ~= nil
		or kind:find("field") ~= nil
		or kind:find("selector") ~= nil
		or kind:find("attribute") ~= nil
		or kind:find("member") ~= nil
		or kind:find("index") ~= nil
		or kind:find("call") ~= nil
end

--- True inside a function body; Go only allows `:=` there.
---@param bufnr integer
---@param row integer
---@param col integer
---@return boolean
local function in_function(bufnr, row, col)
	local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { row, col } })
	while node do
		local kind = node:type()
		if kind == "function_declaration" or kind == "method_declaration" or kind == "func_literal" then
			return true
		end
		node = node:parent()
	end
	return false
end

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
	if not (srow and scol and erow and ecol) then
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
		local ft = vim.bo[bufnr].filetype
		local build = BINDING[ft] or function(n, e)
			return ("%s = %s"):format(n, e)
		end
		if ft == "go" and not in_function(bufnr, srow, scol) then
			build = function(n, e)
				return ("var %s = %s"):format(n, e)
			end
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
	syntax.parsed(bufnr)
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

	local value_node, problem = binding_value(statement, vim.bo[bufnr].filetype)
	if problem then
		Snacks.notify.warn(("`%s` %s; inline one at a time is not supported"):format(name, problem), {
			title = "Refactor",
		})
		return
	end
	local value
	if value_node then
		value = syntax.text(value_node, bufnr)
	else
		-- Grammars without a value field (Lua's assignment_statement) fall back to the text.
		value = (syntax.text(statement, bufnr)):match("=%s*(.+)$")
		value = value and vim.trim(value):gsub(";$", "")
	end
	if not value then
		Snacks.notify.warn("Cannot read the value of this binding", { title = "Refactor" })
		return
	end
	local atomic = value:match("^[%w_%.]+$") ~= nil
		or (
			value_node ~= nil
			and (
					value_node:type():find("literal")
					or value_node:type():find("call")
					or value_node:type():find("parenthesized")
				)
				~= nil
		)

	local plan = Plan.new("Inline " .. name)
	local dsrow, _, derow = statement:range()
	local refs = vim.tbl_filter(function(ref)
		local r, c = ref:start()
		-- The binding's own name is captured as a reference too; its line is deleted anyway.
		if r >= dsrow and r <= derow then
			return false
		end
		if is_member_name(ref) then
			return false
		end
		-- A same-named binding in an inner scope owns the references below it.
		local owner = locals.collides(bufnr, name, r, c)
		return owner ~= nil and owner.node:equal(def.node)
	end, locals.references(bufnr, name, def.scope))

	if #refs == 0 then
		plan:note("skip", bufnr, row, col, "no references; only the binding is removed")
	end
	for _, ref in ipairs(refs) do
		local rrow, rcol = ref:start()
		if is_written(ref, bufnr) then
			plan:note(
				"conflict",
				bufnr,
				rrow,
				rcol,
				("`%s` is assigned or borrowed here; inlining would change what is written"):format(name)
			)
		end
		plan:edit(bufnr, syntax.replace(ref, (atomic or not needs_parens(ref)) and value or ("(" .. value .. ")")))
	end

	plan:edit(bufnr, {
		range = { start = { line = dsrow, character = 0 }, ["end"] = { line = derow + 1, character = 0 } },
		newText = "",
	})

	Plan.finish(plan, opts)
end

return M
