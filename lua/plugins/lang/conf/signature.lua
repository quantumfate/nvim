--- Per-filetype facts the signature refactor needs: which nodes are declarations and
--- calls, where their parameter list hides, and how a parameter is written down.
--- Node types come from `:InspectTree`; verify there when adding a language.

--- 1 when the first parameter is a receiver the call site does not write.
---@param names string[]
---@return fun(node: TSNode): integer
local function receiver(names)
	return function(node)
		for child in node:iter_children() do
			if child:type() == "parameters" or child:type() == "formal_parameters" then
				local first = child:named_child(0)
				local text = first and vim.treesitter.get_node_text(first, 0) or ""
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

---@type table<string, SigLang>
local M = {
	lua = {
		decls = {
			{ node = "function_declaration", list = "parameters" },
			{ node = "function_definition", list = "parameters" },
		},
		calls = { { node = "function_call", list = "arguments" } },
		defaults = false,
		render_param = function(spec)
			return spec.name
		end,
		render_arg = value,
		extra_edits = lua_annotation,
	},

	rust = {
		decls = {
			{
				node = "function_item",
				list = "parameters",
				implicit = function(node)
					local params = node:field("parameters")[1]
					local first = params and params:named_child(0)
					return first and first:type() == "self_parameter" and 1 or 0
				end,
			},
		},
		calls = {
			{ node = "call_expression", list = "arguments" },
			{ node = "method_call_expression", list = "arguments" },
		},
		defaults = false,
		render_param = annotated,
		render_arg = value,
	},

	zig = {
		decls = { { node = "function_declaration", list = "parameters" } },
		calls = { { node = "call_expression", list = "arguments" } },
		defaults = false,
		render_param = annotated,
		render_arg = value,
	},

	go = {
		decls = {
			{ node = "function_declaration", list = "parameter_list" },
			{ node = "method_declaration", list = "parameter_list" },
		},
		calls = { { node = "call_expression", list = "argument_list" } },
		defaults = false,
		render_param = function(spec)
			return spec.name .. (spec.type and (" " .. spec.type) or "")
		end,
		render_arg = value,
	},

	python = {
		decls = { { node = "function_definition", list = "parameters", implicit = receiver({ "self", "cls" }) } },
		calls = { { node = "call", list = "argument_list" } },
		defaults = true,
		render_param = typed,
		render_arg = value,
	},
}

for _, ft in ipairs({ "javascript", "typescript", "typescriptreact", "javascriptreact" }) do
	M[ft] = {
		decls = {
			{ node = "function_declaration", list = "formal_parameters" },
			{ node = "function_expression", list = "formal_parameters" },
			{ node = "arrow_function", list = "formal_parameters" },
			{ node = "method_definition", list = "formal_parameters" },
		},
		calls = { { node = "call_expression", list = "arguments" } },
		defaults = true,
		render_param = typed,
		render_arg = value,
	}
end

return M
