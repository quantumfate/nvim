--- Cursor-aware lookup of the enclosing treesitter textobject.
---@class features.ts_scope
local M = {}

--- Smallest range of `capture` in the textobjects query that contains the cursor.
---@param capture string e.g. "function.outer"
---@return integer[]|nil range 0-indexed { start_row, start_col, end_row, end_col }
function M.enclosing(capture)
	local buf = vim.api.nvim_get_current_buf()
	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not ok or not parser then
		return nil
	end

	-- The queries ship with a lazily loaded plugin, and query.get caches a miss: asked
	-- once before the plugin loads, it answers nil for the rest of the session. So load
	-- first. Move used to report "not inside a function" until something else had.
	pcall(function()
		require("lazy").load({ plugins = { "nvim-treesitter-textobjects" } })
	end)
	local query = vim.treesitter.query.get(parser:lang(), "textobjects")
	local tree = query and parser:parse()[1]
	if not tree then
		return nil
	end

	local cur = vim.api.nvim_win_get_cursor(0)
	local crow, ccol = cur[1] - 1, cur[2]

	local best, best_size
	for id, node in query:iter_captures(tree:root(), buf, 0, -1) do
		if query.captures[id] == capture then
			local sr, sc, er, ec = node:range()
			local contains = (sr < crow or (sr == crow and sc <= ccol)) and (er > crow or (er == crow and ec >= ccol))
			if contains then
				local size = (er - sr) * 1e6 + (ec - sc)
				if not best_size or size < best_size then
					best_size, best = size, { sr, sc, er, ec }
				end
			end
		end
	end

	return best
end

--- Yanks the enclosing `capture` and pastes a copy below it, leaving the cursor
--- on the copy's first line.
---@param capture string
function M.duplicate(capture)
	local range = M.enclosing(capture)
	if not range then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(0, range[1], range[3] + 1, false)
	vim.api.nvim_buf_set_lines(0, range[3] + 1, range[3] + 1, false, vim.list_extend({ "" }, lines))
	vim.api.nvim_win_set_cursor(0, { range[3] + 3, range[2] })
end

return M
