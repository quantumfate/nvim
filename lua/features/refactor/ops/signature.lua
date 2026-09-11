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
---@field implicit? integer|fun(node: TSNode, ctx?: SigCtx, bufnr?: integer): integer Leading entries the writer does not spell out

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
---@param ctx? SigCtx
---@param bufnr? integer Buffer `node` lives in
---@return integer
local function implicit(shape, node, ctx, bufnr)
	local n = shape.implicit or 0
	return type(n) == "function" and n(node, ctx, bufnr) or n --[[@as integer]]
end

--- What a parameter is, for ordering rules: variadic (`*args`, `...rest`, a bare `*`),
--- defaulted, or plain.
---@param node TSNode
---@param bufnr integer
---@return "variadic"|"default"|"plain"
local function param_kind(node, bufnr)
	local kind = node:type()
	local text = syntax.text(node, bufnr)
	if
		kind:find("splat")
		or kind:find("rest")
		or kind:find("variadic")
		or kind:find("separator")
		or text:match("^%*")
		or text:match("^%.%.%.")
	then
		return "variadic"
	end
	if kind:find("default") or kind == "assignment_pattern" or node:field("value")[1] or node:field("default_value")[1] then
		return "default"
	end
	return "plain"
end

--- Why a parameter order would not compile, or nil when it would.
---@param kinds string[]
---@return string?
local function order_problem(kinds)
	local seen_default, seen_variadic = false, false
	for _, kind in ipairs(kinds) do
		if seen_variadic then
			return "a parameter after `*`/`...` is keyword-only or invalid; call sites cannot be updated by position"
		elseif kind == "variadic" then
			seen_variadic = true
		elseif kind == "default" then
			seen_default = true
		elseif seen_default then
			return "a required parameter cannot follow one with a default"
		end
	end
end

--- The name a nameless function is bound to: `const f = () => {}`, `f := func() {}`,
--- `f = lambda: 0`, `local f = function() end`. References are asked there.
---@param decl TSNode
---@return TSNode?
local function binding_name(decl)
	local parent = decl:parent()
	if parent and parent:type():find("expression_list") then
		if parent:named_child_count() ~= 1 then
			return nil
		end
		parent = parent:parent()
	end
	if not parent or parent:type() == "keyword_argument" then
		return nil
	end
	local target = parent:field("name")[1] or parent:field("left")[1] or parent:field("key")[1]
	if not target and parent:type() == "assignment_statement" then
		target = parent:named_child(0)
	end
	while target and target:type():find("list") and target:named_child_count() == 1 do
		target = target:named_child(0)
	end
	if target and (target:type():find("identifier") or target:type():find("index_expression")) then
		return target
	end
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
	-- C: definition > (pointer_declarator >) function_declarator > parameter_list.
	local declarator = node:field("declarator")[1]
	if declarator then
		return list_of(declarator, shape)
	end
end

local C_FAMILY = { c = true, cpp = true, objc = true, cuda = true }

--- The identifier a C declarator names: `add` in `int *add(int)`, `method` in
--- `int Calc::method(int)`.
---@param decl TSNode
---@return TSNode?
local function declarator_name(decl)
	local node = decl:field("declarator")[1]
	while node do
		local inner = node:field("declarator")[1] or node:field("name")[1]
		if not inner then
			break
		end
		node = inner
	end
	return node
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
		-- `y => y * x` has no parameter list to edit; climbing past it would silently
		-- change the function around it instead.
		if node:type() == "arrow_function" and node:field("parameter")[1] then
			return nil
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
	if vim.trim(name):find("%s") then
		Snacks.notify.warn("Write the parameter as `name:type`, e.g. `depth:int`", { title = "Refactor" })
		return nil
	end

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
---@field name_pos? integer[] Where references are asked for: the declaration's (or binding's) name
---@field self_receiver? boolean The first parameter is Python's `self`
---@field owner? string Enclosing class name, for `Class.method(obj, ...)` calls
---@field decl? TSNode The declaration being changed
---@field decl_text? string Rendered new parameter, for other declarations of it
---@field void? TSNode C's `void` standing in for an empty list

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
	ctx.decl = decl
	ctx.params = elements(list)
	ctx.index = cursor_index(list)
	-- C's `(void)` is an empty list spelled with a word in it.
	if #ctx.params == 1 and syntax.text(ctx.params[1], bufnr) == "void" then
		ctx.void, ctx.params, ctx.index = ctx.params[1], {}, 0
	end
	ctx.decl_implicit = implicit(shape, decl, nil, bufnr)

	-- Go's `a, b int` is one node but two arguments, so every index past it is off.
	for _, param in ipairs(ctx.params) do
		if #param:field("name") > 1 then
			Snacks.notify.warn("Grouped parameters (`a, b int`) are not supported; ungroup them first", {
				title = "Refactor",
			})
			return nil
		end
	end

	-- Python's `Class.method(obj, ...)` passes the receiver explicitly; the call-site
	-- shape needs the class name and whether the first parameter is `self` to see it.
	local first = ctx.params[1]
	ctx.self_receiver = ctx.decl_implicit > 0 and first ~= nil and syntax.text(first, bufnr):match("^self%f[^%w_]") ~= nil
	local class = decl:parent()
	while class and class:type() ~= "class_definition" do
		class = class:parent()
	end
	local class_name = class and class:field("name")[1]
	ctx.owner = class_name and syntax.text(class_name, bufnr) or nil

	-- References are asked for at the function's name, never at the cursor: the cursor
	-- is usually inside the parameter list, where the server answers about a parameter.
	--
	-- And at the *last* segment of that name. `function M.area()` has a name field of
	-- `M.area`, whose start is `M` — asking there returns every use of the module
	-- table and not one call of the function.
	local name = decl:field("name")[1] or (C_FAMILY[ft] and declarator_name(decl)) or binding_name(decl)
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
	else
		-- Asking at the cursor instead answers about a parameter, and every call site is
		-- then silently missed.
		Snacks.notify.warn("Anonymous function with no name bound to it: its call sites cannot be found", {
			title = "Refactor",
		})
		return nil
	end
	return ctx, decl, shape
end

--- Applies the declaration edit to another declaration of the same function: a C
--- prototype in a header, or an in-class declaration of an out-of-line definition.
---@param plan refactor.Plan
---@param bufnr integer
---@param list TSNode
---@param ctx SigCtx
local function declaration_site(plan, bufnr, list, ctx)
	local items = elements(list)
	if #items == 1 and syntax.text(items[1], bufnr) == "void" then
		if ctx.mode == "add" and #ctx.params == 0 then
			return plan:edit(bufnr, syntax.replace(items[1], ctx.decl_text))
		end
		items = {}
	end
	if #items ~= #ctx.params then
		local lrow, lcol = list:start()
		return plan:note("skip", bufnr, lrow, lcol, "this declaration has a different parameter count")
	end
	if ctx.mode == "add" then
		return plan:edit(bufnr, edit_for(list, ctx.index, ctx.decl_text, ctx.lang))
	elseif ctx.mode == "remove" then
		return plan:edit(bufnr, remove_edit(list, ctx.index))
	end
	local a, b = items[ctx.index + 1], items[ctx.to + 1]
	plan:edit(bufnr, syntax.replace(a, syntax.text(b, bufnr)))
	plan:edit(bufnr, syntax.replace(b, syntax.text(a, bufnr)))
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

	-- A header opens as cpp and its callers as c: the same family counts as the same
	-- language, and each buffer is read with its own grammar's shapes.
	local parser, ft = parser_for(bufnr)
	local lang = langs()[ft]
	if not parser or not lang or (ft ~= ctx.ft and not (C_FAMILY[ft] and C_FAMILY[ctx.ft])) then
		return note("unparsed or foreign filetype")
	end
	parser:parse(true)

	local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { row, col } })

	if C_FAMILY[ft] then
		local other, other_shape = enclosing(node, lang.decls)
		local named = other and declarator_name(other)
		if named then
			local nrow, ncol = named:start()
			if nrow == row and ncol == col then
				if bufnr == ctx.bufnr and other:equal(ctx.decl) then
					return
				end
				return declaration_site(plan, bufnr, list_of(other, other_shape), ctx)
			end
		end
	end

	local call, shape = (lang.find_call or function(n)
		return enclosing(n, lang.calls)
	end)(node)
	if not call or not shape then
		return note("reference is not a call")
	end

	local list = list_of(call, shape)
	if not list or list:has_error() then
		return note("call does not parse cleanly")
	end

	-- Inside the argument list, the function is passed as a value, not called.
	local lrow, lcol = list:start()
	if row > lrow or (row == lrow and col >= lcol) then
		return note("reference is an argument, not the callee")
	end

	local args = elements(list)
	local receiver = implicit(shape, call, ctx, bufnr)
	local index = ctx.index - ctx.decl_implicit + receiver

	if #args > #ctx.params then
		return note("argument count does not match the declaration")
	end

	-- Positional arguments end at the first keyword argument or splat; past that an
	-- index says nothing about which parameter an argument binds to.
	local positional = #args
	for i, arg in ipairs(args) do
		local kind = arg:type()
		if kind:find("keyword_argument") or kind:find("splat") or kind:find("spread") then
			positional = i - 1
			break
		end
	end

	if ctx.mode == "add" then
		if index > positional then
			return note("earlier optional arguments are absent, or later ones are passed by keyword")
		end
		local text = lang.render_arg(ctx.spec)
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
		if index >= positional then
			return note("argument is passed by keyword or splat")
		end
		return plan:edit(bufnr, remove_edit(list, index))
	end

	-- reorder
	local to = ctx.to - ctx.decl_implicit + receiver
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

	-- C and C++ also need the other declarations (prototypes), which come back only
	-- with the declaration included; call_site tells them apart.
	usages.lsp(ctx.bufnr, { include_declaration = C_FAMILY[ctx.ft] or false, position = ctx.name_pos }, function(found, client, reason)
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
		ctx.decl_text = text
		local decl_edits = { ctx.void and syntax.replace(ctx.void, text) or edit_for(list, ctx.index, text, ctx.lang) }
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
			local kinds = vim.tbl_map(function(param)
				return param_kind(param, ctx.bufnr)
			end, ctx.params)
			local text_kind = (text:match("^%*") or text:match("^%.%.%.")) and "variadic"
				or (spec.default or text:find("=")) and "default"
				or "plain"
			table.insert(kinds, math.min(ctx.index, #kinds) + 1, text_kind)
			local problem = order_problem(kinds)
			if problem then
				local drow, dcol = decl:start()
				plan:note("conflict", ctx.bufnr, drow, dcol, problem)
			end

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
	local index = not ctx.void and cursor_on_index(list) or nil
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
		local kinds = vim.tbl_map(function(param)
			return param_kind(param, ctx.bufnr)
		end, ctx.params)
		kinds[from + 1], kinds[to + 1] = kinds[to + 1], kinds[from + 1]
		local problem = order_problem(kinds)
		if problem then
			local arow, acol = a:start()
			plan:note("conflict", ctx.bufnr, arow, acol, problem)
		end
		Plan.finish(plan, opts)
	end)
end

return M
