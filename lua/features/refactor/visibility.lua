--- Whether a declaration can be seen from outside the file it lives in.
---
--- Not a type question, which is why it belongs here rather than in the ceiling:
--- every language this config touches marks visibility syntactically, and treesitter
--- can read all of it. Moving a file-private symbol somewhere else silently breaks
--- every caller it left behind, and that is worth refusing.
---@class refactor.visibility
local M = {}

local syntax = require("features.refactor.syntax")

---@alias refactor.Visibility "public"|"private"|"unknown"

--- How each language spells "visible outside this file".
---
--- Each returns the visibility of a declaration node, or "unknown" when the language
--- has no syntactic answer and a guess would be worse than admitting it.
---@type table<string, fun(node: TSNode, bufnr: integer): refactor.Visibility>
local RULES = {
	--- `local function f` is file-scoped; `function M.f` is reachable through whatever
	--- the module returns.
	lua = function(node, bufnr)
		local text = syntax.text(node, bufnr)
		if text:match("^%s*local%s") then
			return "private"
		end
		-- A bare `function f()` is a global, and `function M.f()` is exported.
		return "public"
	end,

	--- Rust is explicit: no `pub`, no reach.
	rust = function(node)
		for child in node:iter_children() do
			if child:type() == "visibility_modifier" then
				return "public"
			end
		end
		return "private"
	end,

	--- Go exports by capitalisation of the identifier.
	go = function(node, bufnr)
		local name = node:field("name")[1]
		if not name then
			return "unknown"
		end
		local first = syntax.text(name, bufnr):sub(1, 1)
		return first:match("%u") and "public" or "private"
	end,
}

--- JS, TS and their JSX variants share one rule: reachable only when exported.
local function js_like(node)
	local parent = node:parent()
	while parent do
		local kind = parent:type()
		if kind:find("export") then
			return "public"
		end
		if kind == "program" then
			break
		end
		parent = parent:parent()
	end
	return "private"
end

for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
	RULES[ft] = js_like
end

--- Python has no enforcement, only the leading-underscore convention. Reported as
--- unknown rather than private: refusing a move on a naming convention would be
--- wrong, and claiming it is public would be a lie.
RULES.python = function()
	return "unknown"
end

--- Visibility of a declaration, or "unknown" when the language does not say.
---@param node TSNode
---@param bufnr integer
---@return refactor.Visibility
function M.of(node, bufnr)
	local rule = RULES[vim.bo[bufnr].filetype]
	if not rule then
		return "unknown"
	end
	local ok, result = pcall(rule, node, bufnr)
	return ok and result or "unknown"
end

return M
