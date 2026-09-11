--- Safe delete: remove a declaration only when nothing still uses it.
---
--- The whole point is the refusal. A plain delete is one `dap`; this exists to turn
--- "is anything still calling this?" from a question you ask yourself into one the
--- editor answers, and to make the leftover usages a list you can walk.
---@class refactor.ops.safe_delete
local M = {}

local syntax = require("features.refactor.syntax")
local usages = require("features.refactor.usages")
local Plan = require("features.refactor.plan")

--- Node types that count as a deletable declaration, per language. Falls back to the
--- treesitter textobject when a language is not listed.
---@type table<string, string[]>
local DECLS = {
	lua = { "function_declaration", "function_definition", "assignment_statement", "local_declaration" },
	rust = { "function_item", "struct_item", "enum_item", "const_item", "static_item" },
	go = { "function_declaration", "method_declaration", "type_declaration", "var_declaration" },
	python = { "function_definition", "class_definition" },
	zig = { "function_declaration", "variable_declaration" },
	c = { "function_definition", "declaration" },
	javascript = { "function_declaration", "class_declaration", "lexical_declaration" },
	typescript = { "function_declaration", "class_declaration", "lexical_declaration" },
}

--- The declaration enclosing the cursor, and the identifier naming it.
---@return TSNode?, string?, integer[]?
local function target()
	local bufnr = vim.api.nvim_get_current_buf()
	local parser, ft = syntax.parsed(bufnr)
	if not parser then
		return nil
	end

	local node = vim.treesitter.get_node()
	local decl = syntax.ancestor(node, DECLS[ft] or {})
	if not decl then
		-- Languages without an entry still work through the shared textobject query.
		local range = require("features.ts_scope").enclosing("function.outer")
		if not range then
			return nil
		end
		decl = vim.treesitter.get_node({ bufnr = bufnr, pos = { range[1], range[2] } })
	end
	if not decl then
		return nil
	end

	local name = decl:field("name")[1]
	if not name then
		return decl, nil
	end
	-- The last segment of a dotted name: `function M.orphan()` names `M.orphan`, and
	-- asking the server at its start returns every use of `M`.
	local leaf = name
	while leaf:named_child_count() > 0 do
		local last = leaf:named_child(leaf:named_child_count() - 1)
		if not last then
			break
		end
		leaf = last
	end
	local nrow, ncol = leaf:start()
	return decl, syntax.text(name, bufnr), { nrow, ncol }
end

--- Deletes the declaration under the cursor if nothing references it.
---@param opts? { preview?: boolean }
function M.run(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_get_current_buf()
	local decl, name, name_pos = target()
	if not decl then
		Snacks.notify.warn("Cursor is not inside a declaration", { title = "Refactor" })
		return
	end

	local plan = Plan.new("Safe delete " .. (name or "declaration"))
	-- Decorators belong to the function: left behind, they silently decorate whatever
	-- follows.
	local outer = decl:parent() and decl:parent():type() == "decorated_definition" and decl:parent() or decl
	local srow, scol, erow = outer:range()

	-- Whole lines, doc comment included: deleting the node's exact range would leave
	-- the comment describing it, plus a blank line where the code was.
	local from = syntax.doc_start(bufnr, srow)
	plan:edit(bufnr, {
		range = { start = { line = from, character = 0 }, ["end"] = { line = erow + 1, character = 0 } },
		newText = "",
	})

	usages.lsp(bufnr, { include_declaration = false, position = name_pos }, function(found, _, reason)
		for _, usage in ipairs(found or {}) do
			-- References inside the declaration itself are recursion, not a reason to stop.
			local inside = usage.bufnr == bufnr and usage.range.start.line >= srow and usage.range.start.line <= erow
			if not inside then
				plan:note(
					"conflict",
					usage.bufnr,
					usage.range.start.line,
					usage.range.start.character,
					"still referenced here"
				)
			end
		end

		if not found then
			plan:note(
				"conflict",
				bufnr,
				srow,
				scol,
				(reason or "usages unknown") .. " — cannot verify this is unused"
			)
		end
		Plan.finish(plan, opts)
	end)
end

return M
