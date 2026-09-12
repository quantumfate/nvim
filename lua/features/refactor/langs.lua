--- Per-filetype facts the signature refactor needs: which nodes are declarations and
--- calls, where their parameter list hides, and how a parameter is written down.
--- Node types come from `:InspectTree`; verify there when adding a language.

--- 1 when the first parameter is a receiver the call site does not write.
---@param names string[]
---@return fun(node: TSNode, ctx?: table, bufnr?: integer): integer
local function receiver(names)
	return function(node, _, bufnr)
		for child in node:iter_children() do
			if child:type() == "parameters" or child:type() == "formal_parameters" then
				local first = child:named_child(0)
				-- An override may live in a buffer other than the current one.
				local text = first and vim.treesitter.get_node_text(first, bufnr or 0) or ""
				return vim.tbl_contains(names, vim.split(text, "[,:]")[1]) and 1 or 0
			end
		end
		return 0
	end
end

---@param spec SigParam
---@return string
local function annotated(spec)
	return spec.name .. (spec.type and (": " .. spec.type) or "")
end

---@param spec SigParam
---@return string
local function typed(spec)
	return annotated(spec) .. (spec.default and (" = " .. spec.default) or "")
end

---@param spec SigParam
---@return string
local function value(spec)
	return spec.verbatim or spec.default or spec.name
end

--- Line range of the `---` doc block directly above `row`, or nil when there is none.
---@param bufnr integer
---@param row integer
---@return integer?, integer?
local function doc_block(bufnr, row)
	local last = row - 1
	local first = last
	while first >= 0 do
		local line = vim.api.nvim_buf_get_lines(bufnr, first, first + 1, false)[1] or ""
		if not line:match("^%s*%-%-%-") then
			break
		end
		first = first - 1
	end
	if first == last then
		return nil
	end
	return first + 1, last
end

--- A `---@param` line for the new parameter, placed among the ones already documented.
---@param ctx table
---@param decl TSNode
---@return table[]
local function lua_annotation(ctx, decl)
	local spec = ctx.spec
	if spec.verbatim or not spec.type then
		return {}
	end

	local row = decl:start()
	local first, last = doc_block(ctx.bufnr, row)
	if not first then
		return {}
	end

	local target, seen = nil, 0
	for line = first, last do
		local text = vim.api.nvim_buf_get_lines(ctx.bufnr, line, line + 1, false)[1] or ""
		if text:match("^%s*%-%-%-@param%s") then
			seen = seen + 1
			target = line + 1
			if seen > ctx.index then
				target = line
				break
			end
		elseif text:match("^%s*%-%-%-@return%s") and not target then
			target = line
			break
		end
	end
	target = target or last + 1

	local indent = (vim.api.nvim_buf_get_lines(ctx.bufnr, first, first + 1, false)[1] or ""):match("^%s*")
	local pos = { line = target, character = 0 }
	return {
		{
			range = { start = pos, ["end"] = pos },
			newText = ("%s---@param %s %s\n"):format(indent, spec.name, spec.type),
		},
	}
end

--- 1 when a Rust function's first parameter is `self`, `&self` or `&mut self`.
---@param node TSNode
---@return integer
local function self_parameter(node)
	local params = node:field("parameters")[1]
	local first = params and params:named_child(0)
	return first and first:type() == "self_parameter" and 1 or 0
end

---@type table<string, SigLang>
local M = {
	lua = {
		-- `:` passes the receiver implicitly on either side. A negative count means the
		-- written list has one entry fewer than the logical one.
		decls = {
			{
				node = "function_declaration",
				list = "parameters",
				implicit = function(node)
					local name = node:field("name")[1]
					return name and name:type() == "method_index_expression" and -1 or 0
				end,
			},
			{ node = "function_definition", list = "parameters" },
		},
		calls = {
			{
				node = "function_call",
				list = "arguments",
				implicit = function(call)
					local name = call:field("name")[1]
					return name and name:type() == "method_index_expression" and -1 or 0
				end,
			},
		},
		defaults = false,
		render_param = function(spec)
			return spec.name
		end,
		render_arg = value,
		extra_edits = lua_annotation,
	},

	rust = {
		decls = {
			{ node = "function_item", list = "parameters", implicit = self_parameter },
			-- A trait's declaration: `fn area(&self, x: i32);`
			{ node = "function_signature_item", list = "parameters", implicit = self_parameter },
		},
		calls = {
			{
				node = "call_expression",
				list = "arguments",
				-- `Type::method(&obj, x)` spells out the receiver that `obj.method(x)` hides.
				implicit = function(call, ctx)
					local fn = call:field("function")[1]
					return ctx and ctx.decl_implicit > 0 and fn and fn:type() == "scoped_identifier" and 1 or 0
				end,
			},
			{ node = "method_call_expression", list = "arguments" },
		},
		defaults = false,
		render_param = annotated,
		render_arg = value,
	},

	zig = {
		decls = {
			{
				node = "function_declaration",
				list = "parameters",
				-- `self: *Self` / `self: @This()`: filled by `obj.method()`, spelled out by
				-- `Type.method(&obj)`.
				implicit = function(node, _, bufnr)
					local params = node:field("parameters")[1]
					local first = params and params:named_child(0)
					local text = first and vim.treesitter.get_node_text(first, bufnr or 0) or ""
					return (text:find("Self") or text:find("@This")) and 1 or 0
				end,
			},
		},
		calls = {
			{
				node = "call_expression",
				list = "arguments",
				implicit = function(call, ctx, bufnr)
					if not (ctx and ctx.decl_implicit > 0) then
						return 0
					end
					local fn = call:field("function")[1] or call:named_child(0)
					local object = fn and (fn:field("object")[1] or (fn:named_child_count() > 1 and fn:named_child(0)))
					local text = object and vim.treesitter.get_node_text(object, bufnr or 0) or ""
					-- A type name, by Zig convention capitalised: `Counter.add(&c, 1)`.
					return text:match("^%u") and 1 or 0
				end,
			},
		},
		defaults = false,
		render_param = annotated,
		render_arg = value,
	},

	go = {
		-- Fields, not node types: a method has two `parameter_list` children, and the
		-- first is the receiver.
		decls = {
			{ node = "function_declaration", list = "parameters" },
			{ node = "method_declaration", list = "parameters" },
			{ node = "func_literal", list = "parameters" },
		},
		calls = { { node = "call_expression", list = "arguments" } },
		defaults = false,
		render_param = function(spec)
			return spec.name .. (spec.type and (" " .. spec.type) or "")
		end,
		render_arg = value,
	},

	python = {
		decls = {
			{ node = "function_definition", list = "parameters", implicit = receiver({ "self", "cls" }) },
			{ node = "lambda", list = "parameters" },
		},
		calls = {
			{
				node = "call",
				list = "arguments",
				-- `Shape.scale(s, 7)` passes `self` explicitly; `s.scale(7)` does not. With
				-- overrides in play `Base.scale(self, 7)` inside a subclass counts too.
				implicit = function(call, ctx, bufnr)
					if not (ctx and ctx.self_receiver and ctx.owner) then
						return 0
					end
					local fn = call:field("function")[1]
					local object = fn and fn:type() == "attribute" and fn:field("object")[1]
					if not object then
						return 0
					end
					local text = vim.treesitter.get_node_text(object, bufnr or 0)
					return (text == ctx.owner or (ctx.owners and ctx.owners[text])) and 1 or 0
				end,
			},
		},
		defaults = true,
		render_param = typed,
		render_arg = value,
	},
}

-- C and C++ share a grammar shape here; the declarator holds the parameter list.
for _, ft in ipairs({ "c", "cpp", "objc", "cuda" }) do
	M[ft] = {
		decls = {
			-- The list hangs off the declarator (through pointer/reference declarators
			-- too); list_of follows the `declarator` field down to it.
			{ node = "function_definition", list = "parameter_list" },
			{ node = "declaration", list = "parameter_list" },
			{ node = "field_declaration", list = "parameter_list" },
		},
		calls = { { node = "call_expression", list = "arguments" } },
		defaults = ft ~= "c",
		render_param = function(spec)
			-- C has no inference: a parameter without a type does not compile, so an
			-- omitted one is spelled explicitly rather than silently dropped.
			local default = ft ~= "c" and spec.default and (" = " .. spec.default) or ""
			return (spec.type or "int") .. " " .. spec.name .. default
		end,
		render_arg = value,
	}
end

for _, ft in ipairs({ "javascript", "typescript", "typescriptreact", "javascriptreact" }) do
	M[ft] = {
		decls = {
			{ node = "function_declaration", list = "formal_parameters" },
			{ node = "function_expression", list = "formal_parameters" },
			{ node = "arrow_function", list = "formal_parameters" },
			{ node = "method_definition", list = "formal_parameters" },
			-- Overload signatures, updated together with the implementation.
			{ node = "function_signature", list = "formal_parameters" },
			{ node = "method_signature", list = "formal_parameters" },
		},
		calls = {
			{ node = "call_expression", list = "arguments" },
			{ node = "new_expression", list = "arguments" },
		},
		defaults = true,
		render_param = typed,
		render_arg = value,
	}
end

return M
