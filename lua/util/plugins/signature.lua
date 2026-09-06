--- Signature refactoring: add a parameter to a function declaration and, when the
--- change breaks them, to every call site the language server knows about.
---
--- Language facts come from `plugins/lang/conf/signature.lua`; this module owns the
--- treesitter walking, the list arithmetic, and the edit application.
---@class util.plugins.signature
local M = {}

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
	return require("plugins.lang.conf.signature")
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

--- Parameters or arguments held by a list node, ignoring delimiters and comments.
---@param list TSNode
---@return TSNode[]
local function elements(list)
	local out = {}
	for node in list:iter_children() do
		if node:named() and node:type() ~= "comment" then
			table.insert(out, node)
		end
	end
	return out
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

---@param bufnr integer
---@return vim.treesitter.LanguageTree?, string?
local function parser_for(bufnr)
	local ft = vim.bo[bufnr].filetype
	if ft == "" then
		ft = vim.filetype.match({ buf = bufnr, filename = vim.api.nvim_buf_get_name(bufnr) }) or ""
	end
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, vim.treesitter.language.get_lang(ft))
	return ok and parser or nil, ft
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

---@class SigSite
---@field bufnr integer
---@field edit table
---@class SigSkip
---@field filename string
---@field lnum integer
---@field col integer
---@field text string

--- Turns one reference into either an edit or a skip reason.
---@param loc lsp.Location
---@param encoding string
---@param ctx table
---@return SigSite?, SigSkip?
local function site_for(loc, encoding, ctx)
	local uri = loc.uri or loc.targetUri
	local range = loc.range or loc.targetSelectionRange
	local bufnr = vim.uri_to_bufnr(uri)
	vim.fn.bufload(bufnr)

	local file = vim.uri_to_fname(uri)
	local row, col = to_byte(bufnr, range.start, encoding)
	local skip = function(text)
		return nil, { filename = file, lnum = row + 1, col = col + 1, text = text }
	end

	local parser, ft = parser_for(bufnr)
	if not parser or ft ~= ctx.ft then
		return skip("unparsed or foreign filetype")
	end
	parser:parse(true)

	local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { row, col } })
	local call, shape = (ctx.lang.find_call or function(n)
		return enclosing(n, ctx.lang.calls)
	end)(node)
	if not call or not shape then
		return skip("reference is not a call")
	end

	local list = list_of(call, shape)
	if list:has_error() then
		return skip("call does not parse cleanly")
	end
	local args = elements(list)
	local index = ctx.index - ctx.decl_implicit + implicit(shape, call)

	if #args > #ctx.params then
		return skip("argument count does not match the declaration")
	end
	if index > #args then
		return skip("earlier optional arguments are absent")
	end

	local text = ctx.lang.render_arg(ctx.spec)
	if text == "" then
		return skip("no call-site text for this parameter")
	end
	return { bufnr = bufnr, edit = edit_for(list, index, text, ctx.lang) }, nil
end

---@param edited integer
---@param skips SigSkip[]
local function report(edited, skips)
	if #skips > 0 then
		vim.fn.setqflist({}, " ", { title = "Signature: add parameter", items = skips })
		Snacks.notify.warn(("Added parameter to %d call site(s); %d need attention"):format(edited, #skips))
		return
	end
	Snacks.notify.info(("Added parameter to %d call site(s)"):format(edited))
end

--- Pairs every edit with the buffer it belongs to.
---@param bufnr integer
---@param edits table[]
---@return SigSite[]
local function sites_of(bufnr, edits)
	return vim.tbl_map(function(edit)
		return { bufnr = bufnr, edit = edit }
	end, edits)
end

---@param sites SigSite[]
local function apply(sites)
	local by_buf = {}
	for _, site in ipairs(sites) do
		by_buf[site.bufnr] = by_buf[site.bufnr] or {}
		table.insert(by_buf[site.bufnr], site.edit)
	end
	for bufnr, edits in pairs(by_buf) do
		vim.lsp.util.apply_text_edits(edits, bufnr, "utf-8")
	end
end

---@param ctx table
---@param decl_edits table[]
local function propagate(ctx, decl_edits)
	local client = vim.lsp.get_clients({ bufnr = ctx.bufnr, method = "textDocument/references" })[1]
	if not client then
		apply(sites_of(ctx.bufnr, decl_edits))
		Snacks.notify.warn("No language server: declaration updated, call sites untouched")
		return
	end

	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	params.context = { includeDeclaration = false }

	client:request("textDocument/references", params, function(err, result)
		if err or not result then
			Snacks.notify.error("References failed: " .. (err and err.message or "no result"))
			return
		end

		local sites, skips = sites_of(ctx.bufnr, decl_edits), {}
		local declared = #sites
		local seen = {}
		for _, loc in ipairs(result) do
			local key = (loc.uri or loc.targetUri) .. ":" .. vim.inspect(loc.range or loc.targetSelectionRange)
			if not seen[key] then
				seen[key] = true
				local site, skip = site_for(loc, client.offset_encoding, ctx)
				table.insert(site and sites or skips, site or skip)
			end
		end

		apply(sites)
		report(#sites - declared, skips)
	end, ctx.bufnr)
end

--- Adds a parameter at the cursor's position in the enclosing declaration, updating
--- call sites whenever the new parameter shifts or is required.
---@param opts? { spec?: string, force?: boolean }
function M.add_param(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_get_current_buf()
	local lang = langs()[vim.bo[bufnr].filetype]
	if not lang then
		Snacks.notify.warn("No signature configuration for " .. vim.bo[bufnr].filetype)
		return
	end

	local parser = parser_for(bufnr)
	if not parser then
		Snacks.notify.warn("No treesitter parser for " .. vim.bo[bufnr].filetype)
		return
	end
	parser:parse(true)

	local ctx = { bufnr = bufnr, ft = vim.bo[bufnr].filetype, lang = lang }
	local decl, shape = (lang.find_decl or function()
		return enclosing(vim.treesitter.get_node(), lang.decls)
	end)(ctx)
	if not decl or not shape then
		Snacks.notify.warn("Cursor is not inside a function declaration")
		return
	end

	local proceed = function(input)
		local spec = input and parse_spec(input)
		if not spec then
			return
		end

		local list = list_of(decl, shape)
		ctx.params = elements(list)
		ctx.index = cursor_index(list)
		ctx.decl_implicit = implicit(shape, decl)
		ctx.spec = spec

		local text = spec.verbatim or lang.render_param(spec)
		local decl_edits = { edit_for(list, ctx.index, text, lang) }
		if lang.extra_edits then
			vim.list_extend(decl_edits, lang.extra_edits(ctx, decl) or {})
		end

		local shifts = ctx.index < #ctx.params
		if opts.force or shifts or not lang.defaults or not spec.default then
			-- The declaration edits ride along with the call sites so ranges stay valid.
			propagate(ctx, decl_edits)
			return
		end

		apply(sites_of(bufnr, decl_edits))
		Snacks.notify.info("Added optional parameter; call sites unchanged")
	end

	if opts.spec then
		proceed(opts.spec)
	else
		vim.ui.input({ prompt = "Parameter (name:type=default): " }, proceed)
	end
end

return M
