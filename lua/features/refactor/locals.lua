--- A scope model built from the `locals.scm` queries this config already ships.
---
--- Not a type system — treesitter cannot resolve types — but enough to answer the
--- questions refactorings actually ask: what is in scope here, is this name taken,
--- and where is this local read. That covers name-collision conflicts, safe delete
--- and extract-variable without any language server.
---@class refactor.locals
local M = {}

local syntax = require("features.refactor.syntax")

---@class refactor.Definition
---@field name string
---@field node TSNode The identifier node
---@field scope TSNode Innermost scope containing it

---@param node TSNode
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return boolean
local function contains(node, row, col)
	local srow, scol, erow, ecol = node:range()
	if row < srow or row > erow then
		return false
	end
	if row == srow and col < scol then
		return false
	end
	if row == erow and col > ecol then
		return false
	end
	return true
end

--- Runs the locals query over a buffer.
---@param bufnr integer
---@return { scopes: TSNode[], definitions: refactor.Definition[], references: TSNode[] }|nil
function M.query(bufnr)
	local parser = syntax.parsed(bufnr)
	if not parser then
		return nil
	end
	local lang = parser:lang()
	local ok, query = pcall(vim.treesitter.query.get, lang, "locals")
	if not ok or not query then
		return nil
	end
	local tree = parser:parse()[1]
	if not tree then
		return nil
	end

	local out = { scopes = {}, definitions = {}, references = {} }
	-- A query file inherited twice (javascript inherits ecma, and so does jsx) yields
	-- every capture twice; a parameter then counts as its own second reference.
	local seen = {}
	for id, node in query:iter_captures(tree:root(), bufnr, 0, -1) do
		local capture = query.captures[id]
		local key = capture .. ":" .. node:id()
		if seen[key] then
			capture = nil
		end
		seen[key] = true
		if capture == "local.scope" then
			table.insert(out.scopes, node)
		elseif capture and capture:match("^local%.definition") then
			table.insert(out.definitions, { name = syntax.text(node, bufnr), node = node })
		elseif capture == "local.reference" then
			table.insert(out.references, node)
		end
	end

	-- Pair each definition with the smallest scope that contains it, so shadowing is
	-- visible: two definitions of one name in different scopes are not a collision.
	--
	-- With one correction: a function's name node sits *inside* the function, and the
	-- function is itself a scope. Taken literally that makes `local function f()` a
	-- definition visible only within `f`, so nothing outside can see it. When the
	-- innermost scope is the very thing being named, the definition belongs to the
	-- scope outside it.
	local ordered = out.scopes
	for _, def in ipairs(out.definitions) do
		local row, col = def.node:start()
		local enclosing = {}
		for _, scope in ipairs(ordered) do
			if contains(scope, row, col) then
				table.insert(enclosing, scope)
			end
		end
		table.sort(enclosing, function(a, b)
			local _, _, arow, acol = a:range()
			local _, _, brow, bcol = b:range()
			return arow < brow or (arow == brow and acol < bcol)
		end)

		local index = 1
		local innermost = enclosing[1]
		if innermost then
			local named = innermost:field("name")[1]
			if named and named:equal(def.node) then
				index = 2
			end
		end
		def.scope = enclosing[index]
	end

	return out
end

--- Names defined in every scope enclosing a position, innermost first.
---@param bufnr integer
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return table<string, refactor.Definition> visible
function M.visible(bufnr, row, col)
	local model = M.query(bufnr)
	local out = {}
	if not model then
		return out
	end
	for _, def in ipairs(model.definitions) do
		if not def.scope or contains(def.scope, row, col) then
			out[def.name] = out[def.name] or def
		end
	end
	return out
end

--- Whether a name is already taken at a position. The question behind every
--- "introduce a new name" refactoring.
---@param bufnr integer
---@param name string
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return refactor.Definition|nil clash
function M.collides(bufnr, name, row, col)
	return M.visible(bufnr, row, col)[name]
end

--- Reference nodes matching a name inside a scope. Used by safe delete and by
--- extract-variable to find the occurrences worth replacing.
---@param bufnr integer
---@param name string
---@param scope TSNode|nil Defaults to the whole file
---@return TSNode[]
function M.references(bufnr, name, scope)
	local model = M.query(bufnr)
	if not model then
		return {}
	end
	local out = {}
	for _, node in ipairs(model.references) do
		if syntax.text(node, bufnr) == name then
			local row, col = node:start()
			if not scope or contains(scope, row, col) then
				table.insert(out, node)
			end
		end
	end
	return out
end

--- True when this config ships a locals query for the buffer's language.
---@param bufnr integer
---@return boolean
function M.available(bufnr)
	local parser = syntax.parser(bufnr)
	if not parser then
		return false
	end
	local ok, query = pcall(vim.treesitter.query.get, parser:lang(), "locals")
	return ok and query ~= nil
end

return M
