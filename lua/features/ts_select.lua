--- Node-wise incremental selection: grow the visual selection to the enclosing
--- treesitter node, or shrink back along the path already walked.
---@class features.ts_select
local M = {}

--- Selection history per buffer, innermost range first.
---@type table<integer, integer[][]>
local stack = {}

--- Current visual range as 0-indexed (start_row, start_col, end_row, end_col),
--- or the cursor position when not in visual mode.
---@return integer, integer, integer, integer
local function current_range()
	local mode = vim.fn.mode()
	if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
		local cur = vim.api.nvim_win_get_cursor(0)
		return cur[1] - 1, cur[2], cur[1] - 1, cur[2] + 1
	end
	-- `v` is the anchor end of the selection, `.` the cursor end; order them.
	local s = vim.fn.getpos("v")
	local e = vim.fn.getpos(".")
	local sr, sc, er, ec = s[2] - 1, s[3] - 1, e[2] - 1, e[3]
	if sr > er or (sr == er and sc > ec) then
		sr, sc, er, ec = er, ec - 1, sr, sc + 1
	end
	return sr, sc, er, ec
end

--- Visually selects a 0-indexed range.
---@param range integer[] { start_row, start_col, end_row, end_col }
local function select_range(range)
	local sr, sc, er, ec = range[1], range[2], range[3], range[4]
	if vim.fn.mode() ~= "n" then
		vim.cmd("normal! \27")
	end
	vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
	vim.cmd("normal! v")
	vim.api.nvim_win_set_cursor(0, { er + 1, math.max(0, ec - 1) })
end

--- Grows the selection to the smallest named node that strictly contains it.
function M.expand()
	local buf = vim.api.nvim_get_current_buf()
	local sr, sc, er, ec = current_range()

	local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { sr, sc } })
	if not ok or not node then
		return
	end

	-- Walk up until the node covers more than the current selection.
	while node do
		local nsr, nsc, ner, nec = node:range()
		local wider = (nsr < sr or (nsr == sr and nsc < sc)) or (ner > er or (ner == er and nec > ec))
		if node:named() and wider then
			break
		end
		node = node:parent()
	end
	if not node then
		return
	end

	stack[buf] = stack[buf] or {}
	table.insert(stack[buf], { sr, sc, er, ec })
	select_range({ node:range() })
end

--- Returns to the previous selection recorded by `expand`.
function M.shrink()
	local buf = vim.api.nvim_get_current_buf()
	local history = stack[buf]
	if not history or #history == 0 then
		return
	end
	select_range(table.remove(history))
end

--- Drops the recorded history for a buffer.
---@param buf integer
function M.reset(buf)
	stack[buf] = nil
end

return M
