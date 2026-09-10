--- Treesitter helpers: a text-transform query directive for highlight queries.
---@class features.treesitter
local M = {}

--- Builds a treesitter query directive that rewrites a capture's text through
--- `transform`, storing the result in the match metadata.
---@param transform fun(text: string): string
---@return fun(match: table, _: any, bufnr: integer, pred: table, metadata: table)
function M.case_directive(transform)
	return function(match, _, bufnr, pred, metadata)
		local id = pred[2]
		if type(id) ~= "number" then
			return
		end
		local nodes = match[id]
		if not nodes or #nodes == 0 then
			return
		end
		local node = nodes[1]
		local text = vim.treesitter.get_node_text(node, bufnr, { metadata = metadata[id] }) or ""
		if not metadata[id] then
			metadata[id] = {}
		end
		metadata[id].text = transform(text)
	end
end

return M
