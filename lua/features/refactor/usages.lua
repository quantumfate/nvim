--- Finding every place a symbol is used.
---
--- Two sources, because neither is enough alone: the language server knows which
--- identifiers actually resolve to this symbol, and treesitter knows where the
--- comments and strings are. IntelliJ searches both and lets you tick which to
--- include; LSP rename silently ignores the second, which is why renaming a function
--- leaves its own doc comment talking about the old name.
---@class refactor.usages
local M = {}

local syntax = require("features.refactor.syntax")

---@class refactor.Usage
---@field bufnr integer
---@field range lsp.Range
---@field kind "code"|"comment"|"string"
---@field opened? boolean True when finding this usage is what loaded the buffer

--- Asks the language server for references. Async: `on_done` receives the list, or
--- nil when no server can answer.
---
--- `position` matters more than it looks. Asking at the cursor is wrong whenever the
--- cursor is not on the symbol being refactored — inside a parameter list, say, where
--- the server answers about the parameter and the call sites are never found. Callers
--- pass the position of the name they mean.
---@param bufnr integer
---@param opts { include_declaration?: boolean, position?: integer[] } position is {row, col}, 0-indexed
---@param on_done fun(usages: refactor.Usage[]|nil, client: vim.lsp.Client|nil, reason: string?)
function M.lsp(bufnr, opts, on_done)
	local client = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/references" })[1]
	if not client then
		on_done(nil, nil, "no language server for this buffer")
		return
	end

	local params
	if opts.position then
		local row, col = opts.position[1], opts.position[2]
		local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
		local ok, character = pcall(vim.str_utfindex, line, client.offset_encoding, col, false)
		params = {
			textDocument = { uri = vim.uri_from_bufnr(bufnr) },
			position = { line = row, character = ok and character or col },
		}
	else
		params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	end
	params.context = { includeDeclaration = opts.include_declaration ~= false }

	-- A cold server can take many seconds to answer, during which the editor looks
	-- like it ignored the keypress. Only says anything if the wait is actually long.
	local answered = false
	vim.defer_fn(function()
		if not answered then
			Snacks.notify.info("Waiting for " .. client.name .. " to find usages…", { title = "Refactor" })
		end
	end, 1500)

	client:request("textDocument/references", params, function(err, result)
		answered = true
		if err then
			on_done(nil, client, "references failed: " .. (err.message or "unknown error"))
			return
		end
		if not result or vim.tbl_isempty(result) then
			-- A real answer, just an empty one: nothing references this symbol.
			on_done({}, client)
			return
		end

		local out, seen = {}, {}
		for _, loc in ipairs(result) do
			local uri = loc.uri or loc.targetUri
			local range = loc.range or loc.targetSelectionRange
			local key = uri .. ":" .. range.start.line .. ":" .. range.start.character
			if not seen[key] then
				seen[key] = true
				local target = vim.uri_to_bufnr(uri)
				-- Whether this search is what opened the file decides, later, if the plan
				-- may write it. Read before bufload, which makes it true either way.
				local was_loaded = vim.api.nvim_buf_is_loaded(target)
				vim.fn.bufload(target)
				table.insert(out, { bufnr = target, range = range, kind = "code", opened = not was_loaded })
			end
		end
		on_done(out, client)
	end, bufnr)
end

--- Occurrences of `name` inside comments and strings that read as references to the
--- symbol rather than as ordinary prose.
---
--- A plain word match is not good enough. Renaming `area` to `rect_area` would rewrite
--- "Computes the area of a rectangle" into "Computes the rect_area of a rectangle" —
--- the identifier and the English word are spelled the same, and only the surrounding
--- punctuation says which one is meant. So a match counts only where the text is
--- shaped like code: a call, a member access, a backticked name, or a doc-tag operand.
---
--- `loose = true` drops that requirement and takes every whole-word hit.
---@param bufnr integer
---@param name string
---@param opts? { loose?: boolean }
---@return refactor.Usage[]
function M.prose(bufnr, name, opts)
	opts = opts or {}
	local parser = syntax.parsed(bufnr)
	if not parser then
		return {}
	end
	local tree = parser:parse()[1]
	if not tree then
		return {}
	end

	local escaped = vim.pesc(name)
	local word = "%f[%w_]" .. escaped .. "%f[^%w_]"

	--- Whether the hit at [from, to) is being used as a symbol.
	---@param text string The whole comment or string
	---@param from integer
	---@param to integer
	---@return boolean
	local function is_reference(text, from, to)
		local before = text:sub(1, from - 1)
		local after = text:sub(to + 1)
		return after:match("^%s*%(") ~= nil -- area(  — a call
			or after:match("^[.:]") ~= nil -- area.x / area:x  — a receiver
			or before:match("[.:]$") ~= nil -- M.area  — a member
			or (before:match("`$") and after:match("^`")) ~= nil -- `area`  — quoted as code
			or before:match("@%w+%s+$") ~= nil -- @param area  — a doc tag operand
			or after:match("^%(%)") ~= nil -- area()
	end

	local out = {}

	--- Walks the tree for comment and string nodes, scanning their text.
	---@param node TSNode
	local function walk(node)
		local kind = node:type()
		local is_comment = kind:find("comment") ~= nil
		local is_string = kind:find("string") ~= nil

		if is_comment or is_string then
			local srow, scol = node:start()
			local text = syntax.text(node, bufnr)
			local index = 1
			while true do
				local from, to = text:find(word, index)
				if not from then
					break
				end
				if opts.loose or is_reference(text, from, to) then
					-- Translate the byte offset inside the node back to a buffer position.
					local before = text:sub(1, from - 1)
					local newlines = select(2, before:gsub("\n", ""))
					local last = before:match("[^\n]*$") or ""
					local row = srow + newlines
					local col = (newlines == 0 and scol or 0) + #last
					table.insert(out, {
						bufnr = bufnr,
						range = {
							start = { line = row, character = col },
							["end"] = { line = row, character = col + #name },
						},
						kind = is_comment and "comment" or "string",
					})
				end
				index = to + 1
			end
			return
		end

		for child in node:iter_children() do
			walk(child)
		end
	end

	walk(tree:root())
	return out
end

return M
