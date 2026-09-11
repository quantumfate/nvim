--- Treesitter helpers shared by every refactoring.
---
--- Extracted from the signature refactor, which was the only caller when it was the
--- only refactoring. Nothing here knows what is being refactored.
---@class refactor.syntax
local M = {}

--- The parser for a buffer, plus the filetype it was resolved from.
---@param bufnr integer
---@return vim.treesitter.LanguageTree?, string ft
function M.parser(bufnr)
	local ft = vim.bo[bufnr].filetype
	if ft == "" then
		ft = vim.filetype.match({ buf = bufnr, filename = vim.api.nvim_buf_get_name(bufnr) }) or ""
	end
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, vim.treesitter.language.get_lang(ft))
	return ok and parser or nil, ft
end

--- Parses a buffer and returns its parser, or nil when it has no grammar.
---@param bufnr integer
---@return vim.treesitter.LanguageTree?, string ft
function M.parsed(bufnr)
	local parser, ft = M.parser(bufnr)
	if parser then
		parser:parse(true)
	end
	return parser, ft
end

--- Named, non-comment children of a node — the entries of a list, ignoring syntax.
---@param node TSNode
---@return TSNode[]
function M.elements(node)
	local out = {}
	for child in node:iter_children() do
		-- C's `...` is an unnamed token but a real entry: without it, the entry before
		-- it looks last and an insert lands between `fmt,` and `...`.
		if (child:named() and child:type() ~= "comment") or child:type() == "..." then
			table.insert(out, child)
		end
	end
	return out
end

--- Nearest ancestor (including `node`) whose type is in `types`.
---@param node TSNode?
---@param types string[]
---@return TSNode?
function M.ancestor(node, types)
	while node do
		if vim.tbl_contains(types, node:type()) then
			return node
		end
		node = node:parent()
	end
end

--- Byte column for an LSP position, which counts UTF-16 code units by default.
---@param bufnr integer
---@param pos lsp.Position
---@param encoding string
---@return integer row, integer col
function M.to_byte(bufnr, pos, encoding)
	local line = vim.api.nvim_buf_get_lines(bufnr, pos.line, pos.line + 1, false)[1] or ""
	local ok, col = pcall(vim.str_byteindex, line, encoding, pos.character, false)
	return pos.line, ok and col or math.min(pos.character, #line)
end

--- An LSP TextEdit covering a node's range.
---@param node TSNode
---@param text string
---@return lsp.TextEdit
function M.replace(node, text)
	local srow, scol, erow, ecol = node:range()
	return {
		range = { start = { line = srow, character = scol }, ["end"] = { line = erow, character = ecol } },
		newText = text,
	}
end

--- An LSP TextEdit inserting text at a point.
---@param row integer 0-indexed
---@param col integer 0-indexed byte column
---@param text string
---@return lsp.TextEdit
function M.insert(row, col, text)
	local pos = { line = row, character = col }
	return { range = { start = pos, ["end"] = pos }, newText = text }
end

--- The identifier naming a parameter, found by descending rather than by splitting
--- its text.
---
--- Text splitting cannot do this: `mut x: i32` and `*mut T` both start with a
--- modifier, `&self` with punctuation, and the first whitespace- or colon-delimited
--- token is the wrong answer for all three. Getting it wrong makes a "is this still
--- used?" check search for `mut`, find nothing, and call an unsafe removal safe.
---@param node TSNode The parameter node
---@param bufnr integer
---@return string? name
function M.param_name(node, bufnr)
	if node:type() == "identifier" then
		return M.text(node, bufnr)
	end

	-- A parameter's name is the first identifier in it: the type, default value and
	-- any modifiers all come after.
	-- C puts the name in the declarator (`const Foo &f`), after the type.
	local named = node:field("name")[1] or node:field("pattern")[1] or node:field("declarator")[1]
	if named then
		return M.param_name(named, bufnr)
	end

	for child in node:iter_children() do
		if child:named() then
			local kind = child:type()
			local is_type = kind:find("type") or kind == "namespace_identifier"
			if kind == "identifier" or (kind:find("identifier") and not is_type) then
				return M.text(child, bufnr)
			end
			local nested = M.param_name(child, bufnr)
			if nested then
				return nested
			end
		end
	end

	-- Self parameters and varargs have no identifier of their own.
	return nil
end

--- First row of the comment block directly above `row`, or `row` itself when there is
--- none.
---
--- A declaration's doc comment is not part of its node, so deleting or moving the
--- declaration alone strips the code and leaves the prose describing it behind,
--- attached to whatever follows.
---@param bufnr integer
---@param row integer 0-indexed row of the declaration
---@return integer first_row
function M.doc_start(bufnr, row)
	-- Parsed, not just fetched: a buffer nobody has displayed (a call site the plan
	-- opened, a headless run) has no tree yet, and get_node then finds nothing.
	local parser = M.parsed(bufnr)
	if not parser then
		return row
	end

	local first = row
	for candidate = row - 1, 0, -1 do
		local line = vim.api.nvim_buf_get_lines(bufnr, candidate, candidate + 1, false)[1]
		if not line or vim.trim(line) == "" then
			break
		end
		-- Ask treesitter rather than matching comment syntax per language.
		local node = vim.treesitter.get_node({
			bufnr = bufnr,
			pos = { candidate, math.max(#(line:match("^%s*") or ""), 0) },
		})
		-- Attributes (`#[inline]`) travel with the item like its doc comment does.
		local attached = false
		while node and node:start() == candidate do
			local kind = node:type()
			if kind:find("comment") or kind == "attribute_item" or kind == "decorator" then
				attached = true
				break
			end
			node = node:parent()
		end
		if not attached then
			break
		end
		first = candidate
	end
	return first
end

--- Text of a node, read from the buffer it belongs to.
---@param node TSNode
---@param bufnr integer
---@return string
function M.text(node, bufnr)
	return vim.treesitter.get_node_text(node, bufnr)
end

return M
