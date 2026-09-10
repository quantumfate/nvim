--- Change signature: add, remove or reorder a parameter, updating every call site the
--- language server knows about.
---
--- Ported from the standalone engine that predated refactor.Plan. The analysis is
--- unchanged; what changed is the ending — it now returns a plan instead of writing
--- to buffers, so preview, conflict gating and one-step undo come from the shared
--- machinery rather than from here.
---@class refactor.ops.signature
local M = {}

local syntax = require("features.refactor.syntax")
local locals = require("features.refactor.locals")
local usages = require("features.refactor.usages")
local Plan = require("features.refactor.plan")

local elements = syntax.elements
local to_byte = syntax.to_byte

local function parser_for(bufnr)
	return syntax.parser(bufnr)
end

---@class SigParam
---@field name string
---@field type? string
---@field default? string
---@field verbatim? string Raw text, bypassing render_param

---@class SigShape
---@field node string Treesitter node type
---@field list string Field name of the parameter/argument list, or its node type
---@field implicit? integer|fun(node: TSNode): integer Leading entries the writer does not spell out

---@class SigLang
---@field decls SigShape[]
---@field calls SigShape[]
---@field defaults boolean Language supports default parameter values
---@field render_param fun(spec: SigParam): string
---@field render_arg fun(spec: SigParam): string
---@field find_decl? fun(ctx: table): TSNode?, SigShape?
---@field find_call? fun(node: TSNode): TSNode?, SigShape?
---@field insert_pos? fun(list: TSNode, index: integer): integer, integer, string, string
---@field extra_edits? fun(ctx: table, decl: TSNode): table[] Edits beside the parameter list, e.g. doc comments

local function langs()
	return require("features.refactor.langs")
end

---@param shapes SigShape[]
---@param node TSNode
---@return SigShape?
local function shape_for(shapes, node)
	for _, shape in ipairs(shapes) do
		if shape.node == node:type() then
			return shape
		end
	end
end

---@param shape SigShape
---@param node TSNode
---@return integer
local function implicit(shape, node)
	local n = shape.implicit or 0
	return type(n) == "function" and n(node) or n --[[@as integer]]
end

--- The parameter/argument list of `node`, by field where the grammar has one and by
--- child type where it does not (Zig).
---@param node TSNode
---@param shape SigShape
---@return TSNode?
local function list_of(node, shape)
	local field = node:field(shape.list)[1]
	if field then
		return field
	end
	for child in node:iter_children() do
		if child:type() == shape.list then
			return child
		end
	end
end

--- Nearest enclosing node matching one of `shapes`.
---@param node TSNode?
---@param shapes SigShape[]
---@return TSNode?, SigShape?
local function enclosing(node, shapes)
	while node do
		local shape = shape_for(shapes, node)
		if shape and list_of(node, shape) then
			return node, shape
		end
		node = node:parent()
	end
end

--- Splits `name:type=default` into its parts; a leading `!` keeps the text verbatim.
---@param input string
---@return SigParam?
local function parse_spec(input)
	input = vim.trim(input)
	if input == "" then
		return nil
	end
	if input:sub(1, 1) == "!" then
		return { name = "", verbatim = vim.trim(input:sub(2)) }
	end

	local left, default = input:match("^([^=]+)=(.*)$")
	left = left or input
	local name, type_ = left:match("^([^:]+):(.*)$")
	name = name or left

	return {
		name = vim.trim(name),
		type = type_ and vim.trim(type_) or nil,
		default = default and vim.trim(default) or nil,
	}
end

--- Where new text goes to become the `index`-th entry of `list`, with the separators
--- the surrounding style needs.
---@param list TSNode
---@param index integer
---@return integer row, integer col, string prefix, string suffix
local function insert_pos(list, index)
	local items = elements(list)

	if #items == 0 then
		local closer = list:child(list:child_count() - 1)
		local row, col = closer:start()
		return row, col, "", ""
	end

	if index >= #items then
		local last = items[#items]
		local row, col = last:end_()
		local after = last:next_sibling()
		if after and not after:named() and after:type() == "," then
			row, col = after:end_()
			return row, col, " ", ""
		end
		return row, col, ", ", ""
	end

	local row, col = items[index + 1]:start()
	return row, col, "", ", "
end

---@param list TSNode
---@param index integer
---@param text string
---@param lang SigLang
---@return table edit
local function edit_for(list, index, text, lang)
	local row, col, prefix, suffix = (lang.insert_pos or insert_pos)(list, index)
	local pos = { line = row, character = col }
	return { range = { start = pos, ["end"] = pos }, newText = prefix .. text .. suffix }
end

--- Deletes the `index`-th entry of `list`, taking one separator with it so the
--- remaining entries stay comma-correct. Removing the last entry eats the separator
--- *before* it instead of a trailing one that is not there.
---@param list TSNode
---@param index integer
---@return lsp.TextEdit
local function remove_edit(list, index)
	local items = elements(list)
	local target = items[index + 1]
	local srow, scol, erow, ecol = target:range()

	local after = target:next_sibling()
	if after and not after:named() and after:type() == "," then
		-- Take the comma and any space that follows it.
		local nxt = items[index + 2]
		if nxt then
			erow, ecol = nxt:start()
		else
			erow, ecol = after:end_()
		end
	else
		local before = target:prev_sibling()
		if before and not before:named() and before:type() == "," then
			srow, scol = before:start()
		end
	end

	return {
		range = { start = { line = srow, character = scol }, ["end"] = { line = erow, character = ecol } },
		newText = "",
	}
end

--- Index the cursor points at within `list`: the number of entries starting before it.
---@param list TSNode
---@return integer
local function cursor_index(list)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]
	local lrow, lcol, erow, ecol = list:range()

	local inside = (lrow < row or (lrow == row and lcol <= col)) and (erow > row or (erow == row and ecol >= col))
	local items = elements(list)
	if not inside then
		return #items
	end

	local index = 0
	for _, item in ipairs(items) do
		local srow, scol = item:start()
		if srow < row or (srow == row and scol < col) then
			index = index + 1
		end
	end
	return index
end

--- Index of the entry the cursor sits inside, or nil when it is between entries.
---
--- Not the same question as `cursor_index`, which counts the entries starting before
--- the cursor so a new one can be inserted there. Removing and reordering need the
--- entry the cursor is *on*.
---@param list TSNode
---@return integer? index 0-based
local function cursor_on_index(list)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]
	for i, item in ipairs(elements(list)) do
		local srow, scol, erow, ecol = item:range()
		local after_start = row > srow or (row == srow and col >= scol)
		local before_end = row < erow or (row == erow and col <= ecol)
		if after_start and before_end then
			return i - 1
		end
	end
	return nil
end

---@param bufnr integer
---@param pos lsp.Position
---@param encoding string
---@return integer row, integer col
local function to_byte(bufnr, pos, encoding)
	local line = vim.api.nvim_buf_get_lines(bufnr, pos.line, pos.line + 1, false)[1] or ""
	local ok, col = pcall(vim.str_byteindex, line, encoding, pos.character, false)
	return pos.line, ok and col or math.min(pos.character, #line)
end
--- Shared context for one signature change.
---@class SigCtx
---@field bufnr integer
---@field ft string
---@field lang SigLang
---@field params TSNode[]
---@field index integer
---@field decl_implicit integer
---@field spec? SigParam
---@field mode "add"|"remove"|"reorder"
---@field to? integer Destination index, for reorder

--- Locates the declaration under the cursor and gathers everything both the
--- declaration edit and the call-site walk need.
---@return SigCtx?, TSNode?, SigShape?
local function context()
	local bufnr = vim.api.nvim_get_current_buf()
	local ft = vim.bo[bufnr].filetype
	local lang = langs()[ft]
	if not lang then
		Snacks.notify.warn("No signature configuration for " .. ft, { title = "Refactor" })
		return nil
	end

	local parser = parser_for(bufnr)
	if not parser then
		Snacks.notify.warn("No treesitter parser for " .. ft, { title = "Refactor" })
		return nil
	end
	parser:parse(true)

	local ctx = { bufnr = bufnr, ft = ft, lang = lang }
	local decl, shape = (lang.find_decl or function()
		return enclosing(vim.treesitter.get_node(), lang.decls)
	end)(ctx)
	if not decl or not shape then
		Snacks.notify.warn("Cursor is not inside a function declaration", { title = "Refactor" })
		return nil
	end

	local list = list_of(decl, shape)
	ctx.params = elements(list)
	ctx.index = cursor_index(list)
	ctx.decl_implicit = implicit(shape, decl)

	-- References are asked for at the function's name, never at the cursor: the cursor
	-- is usually inside the parameter list, where the server answers about a parameter.
	--
	-- And at the *last* segment of that name. `function M.area()` has a name field of
	-- `M.area`, whose start is `M` — asking there returns every use of the module
	-- table and not one call of the function.
	local name = decl:field("name")[1]
	if name then
		while name:named_child_count() > 0 do
			local last = name:named_child(name:named_child_count() - 1)
			if not last or last:type() ~= "identifier" and last:named_child_count() == 0 then
				break
			end
			name = last
		end
		local nrow, ncol = name:start()
		ctx.name_pos = { nrow, ncol }
	end
	return ctx, decl, shape
end

--- Rewrites one call site, or explains why it was left alone.
---@param plan refactor.Plan
---@param usage refactor.Usage
---@param encoding string
---@param ctx SigCtx
local function call_site(plan, usage, encoding, ctx)
	local bufnr = usage.bufnr
	local row, col = to_byte(bufnr, usage.range.start, encoding)
	local note = function(text)
		plan:note("skip", bufnr, row, col, text)
	end

	local parser, ft = parser_for(bufnr)
	if not parser or ft ~= ctx.ft then
		return note("unparsed or foreign filetype")
	end
	parser:parse(true)

	local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { row, col } })
	local call, shape = (ctx.lang.find_call or function(n)
		return enclosing(n, ctx.lang.calls)
	end)(node)
	if not call or not shape then
		return note("reference is not a call")
	end

	local list = list_of(call, shape)
	if not list or list:has_error() then
		return note("call does not parse cleanly")
	end

	local args = elements(list)
	local index = ctx.index - ctx.decl_implicit + implicit(shape, call)

	if #args > #ctx.params then
		return note("argument count does not match the declaration")
	end

	if ctx.mode == "add" then
		if index > #args then
			return note("earlier optional arguments are absent")
		end
		local text = ctx.lang.render_arg(ctx.spec)
		if text == "" then
			return note("no call-site text for this parameter")
		end
		return plan:edit(bufnr, edit_for(list, index, text, ctx.lang))
	end

	if ctx.mode == "remove" then
		local target = args[index + 1]
		if not target then
			return note("argument is already absent")
		end
		return plan:edit(bufnr, remove_edit(list, index))
	end

	-- reorder
	local to = ctx.to - ctx.decl_implicit + implicit(shape, call)
	local from_node, to_node = args[index + 1], args[to + 1]
	if not from_node or not to_node then
		return note("argument positions are not both present")
	end

	-- Named arguments bind to a parameter by name, not by position: swapping their
	-- text would rewrite `f(a=1, b=2)` into `f(b=2, a=1)`, which means the same thing,
	-- while swapping only one of a mixed pair silently changes what is passed.
	for _, arg in ipairs({ from_node, to_node }) do
		local kind = arg:type()
		if kind:find("keyword_argument") or kind:find("named_argument") or kind == "field_initializer" then
			return note("call uses named arguments, where order carries no meaning")
		end
	end
	plan:edit(bufnr, syntax.replace(from_node, syntax.text(to_node, bufnr)))
	plan:edit(bufnr, syntax.replace(to_node, syntax.text(from_node, bufnr)))
end

--- Runs the call-site walk and hands the finished plan to `done`.
---@param ctx SigCtx
---@param decl_edits lsp.TextEdit[]
---@param title string
---@param done fun(plan: refactor.Plan)
local function build(ctx, decl_edits, title, done)
	local plan = Plan.new(title)
	plan:edits_for(ctx.bufnr, decl_edits)

	usages.lsp(ctx.bufnr, { include_declaration = false, position = ctx.name_pos }, function(found, client, reason)
		if not found then
			plan:note("skip", ctx.bufnr, 0, 0, (reason or "no usages available") .. "; call sites untouched")
			done(plan)
			return
		end
		for _, usage in ipairs(found) do
			if usage.opened or Plan.owns(usage.bufnr) then
				plan:adopt(usage.bufnr)
			end
			call_site(plan, usage, client.offset_encoding, ctx)
		end
		done(plan)
	end)
end

--- Adds a parameter at the cursor's position in the enclosing declaration.
---@param opts? { spec?: string, force?: boolean, preview?: boolean }
function M.add_param(opts)
	opts = opts or {}
	if not Plan.begin("Add parameter") then
		return
	end
	local ctx, decl, shape = context()
	if not ctx then
		Plan.done()
		return
	end

	local proceed = function(input)
		local spec = input and parse_spec(input)
		if not spec then
			-- Prompt dismissed.
			Plan.done()
			return
		end
		ctx.mode, ctx.spec = "add", spec

		local list = list_of(decl, shape)
		local text = spec.verbatim or ctx.lang.render_param(spec)
		local decl_edits = { edit_for(list, ctx.index, text, ctx.lang) }
		if ctx.lang.extra_edits then
			vim.list_extend(decl_edits, ctx.lang.extra_edits(ctx, decl) or {})
		end

		local title = "Add parameter " .. (spec.name ~= "" and spec.name or spec.verbatim)

		-- A new name that is already taken in this scope compiles to something that
		-- silently shadows. The language server cannot see the parameter yet, so the
		-- locals model is the only thing that can catch it.
		local shifts = ctx.index < #ctx.params
		local optional = ctx.lang.defaults and spec.default and not shifts and not opts.force

		local finish = function(plan)
			if spec.name == "" then
				plan:skipped_check("collision detection", "the parameter text is verbatim, with no name to check")
			elseif not locals.available(ctx.bufnr) then
				plan:skipped_check("collision detection", "no locals query for " .. ctx.ft)
			else
				local drow, dcol = decl:start()
				local clash = locals.collides(ctx.bufnr, spec.name, drow, dcol)
				if clash then
					local crow, ccol = clash.node:start()
					plan:note("conflict", ctx.bufnr, crow, ccol, ("`%s` is already in scope here"):format(spec.name))
				end
			end
			Plan.finish(plan, opts)
		end

		if optional then
			-- Nothing downstream breaks, so the call sites are left alone entirely.
			local plan = Plan.new(title .. " (optional)")
			plan:edits_for(ctx.bufnr, decl_edits)
			finish(plan)
			return
		end
		build(ctx, decl_edits, title, finish)
	end

	if opts.spec then
		proceed(opts.spec)
	else
		vim.ui.input({ prompt = "Parameter (name:type=default): " }, proceed)
	end
end

--- Removes the parameter under the cursor, and its argument at every call site.
---@param opts? { preview?: boolean }
function M.remove_param(opts)
	opts = opts or {}
	if not Plan.begin("Remove parameter") then
		return
	end
	local ctx, decl, shape = context()
	if not ctx then
		Plan.done()
		return
	end

	local list = list_of(decl, shape)
	local index = cursor_on_index(list)
	if not index then
		Snacks.notify.warn("Cursor is not on a parameter", { title = "Refactor" })
		Plan.done()
		return
	end
	ctx.index = index
	local target = ctx.params[index + 1]
	local srow, scol = target:start()

	ctx.mode = "remove"
	local name = syntax.text(target, ctx.bufnr)
	local ident = syntax.param_name(target, ctx.bufnr)
	local title = "Remove parameter " .. (ident or name)

	build(ctx, { remove_edit(list, ctx.index) }, title, function(plan)
		-- Removing a parameter still referenced in the body leaves code that does not
		-- compile, which is exactly what "safe" means in Safe Delete.
		if not locals.available(ctx.bufnr) then
			plan:skipped_check("still-used check", "no locals query for " .. ctx.ft)
		elseif not ident then
			-- No identifier to look for (a self parameter, varargs, a destructured
			-- pattern): say so rather than reporting a clean bill of health.
			plan:note("conflict", ctx.bufnr, srow, scol, "cannot read this parameter's name to check for uses")
		else
			local body_refs = locals.references(ctx.bufnr, ident, decl)
			if #body_refs > 1 then
				local rrow, rcol = body_refs[2]:start()
				plan:note(
					"conflict",
					ctx.bufnr,
					rrow,
					rcol,
					("`%s` is still used in the body (%d references)"):format(ident, #body_refs - 1)
				)
			end
		end
		Plan.finish(plan, opts)
	end)
end

--- Swaps the parameter under the cursor with its neighbour, at the declaration and
--- at every call site.
---@param opts? { direction?: "next"|"prev", preview?: boolean }
function M.reorder_param(opts)
	opts = opts or {}
	if not Plan.begin("Reorder parameters") then
		return
	end
	local ctx, decl, shape = context()
	if not ctx then
		Plan.done()
		return
	end

	local from = cursor_on_index(list_of(decl, shape))
	if not from then
		Snacks.notify.warn("Cursor is not on a parameter", { title = "Refactor" })
		Plan.done()
		return
	end
	ctx.index = from

	local to = opts.direction == "prev" and from - 1 or from + 1
	local a, b = ctx.params[from + 1], ctx.params[to + 1]
	if not a or not b then
		Snacks.notify.warn("No neighbouring parameter to swap with", { title = "Refactor" })
		Plan.done()
		return
	end

	ctx.mode, ctx.to = "reorder", to
	local decl_edits = {
		syntax.replace(a, syntax.text(b, ctx.bufnr)),
		syntax.replace(b, syntax.text(a, ctx.bufnr)),
	}
	build(ctx, decl_edits, "Reorder parameters", function(plan)
		Plan.finish(plan, opts)
	end)
end

return M
