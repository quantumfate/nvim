--- Treesitter helpers: a text-transform query directive and cursor-aware function
--- selection for textobjects.
---@class util.plugins.treesitter
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

--- Visually selects the smallest textobject range of `capture` containing the cursor.
---@param capture string e.g. "function.outer" / "function.inner"
function M.select_function(capture)
	local bufnr = vim.api.nvim_get_current_buf()
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not ok or not parser then
		return
	end

	local lang = parser:lang()
	local query = vim.treesitter.query.get(lang, "textobjects")
	if not query then
		return
	end

	local tree = parser:parse()[1]
	if not tree then
		return
	end
	local root = tree:root()

	local cur = vim.api.nvim_win_get_cursor(0)
	local crow, ccol = cur[1] - 1, cur[2]

	-- Keep the smallest capture range that still contains the cursor.
	local best, best_size
	for _, match in query:iter_matches(root, bufnr, 0, -1, { all = true }) do
		-- Widest span across all nodes of this match's capture.
		local min_sr, min_sc, max_er, max_ec
		for id, nodes in pairs(match) do
			if query.captures[id] == capture then
				if type(nodes) ~= "table" then
					nodes = { nodes }
				end
				for _, node in ipairs(nodes) do
					local sr, sc, er, ec = node:range()
					if not min_sr or sr < min_sr or (sr == min_sr and sc < min_sc) then
						min_sr, min_sc = sr, sc
					end
					if not max_er or er > max_er or (er == max_er and ec > max_ec) then
						max_er, max_ec = er, ec
					end
				end
			end
		end
		if min_sr then
			local contains = (min_sr < crow or (min_sr == crow and min_sc <= ccol))
				and (max_er > crow or (max_er == crow and max_ec >= ccol))
			if contains then
				local size = (max_er - min_sr) * 1e6 + (max_ec - min_sc)
				if not best_size or size < best_size then
					best_size = size
					best = { min_sr, min_sc, max_er, max_ec }
				end
			end
		end
	end

	if not best then
		return
	end
	local sr, sc, er, ec = best[1], best[2], best[3], best[4]

	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
	end

	vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
	vim.cmd("normal! v")
	vim.api.nvim_win_set_cursor(0, { er + 1, math.max(0, ec - 1) })
end
return M
