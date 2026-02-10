M = {}

---Saves the curront window's cursor position
---@return table win_pos { win = win, pos = pos }
function M.save_win_and_cursor()
	local win = vim.api.nvim_get_current_win()
	local pos = vim.api.nvim_win_get_cursor(win)
	return { win = win, pos = pos }
end

---Move the cursor to the specified position
---@param state table { win = win, pos = pos }
function M.restore_win_and_cursor(state)
	if not state then
		return
	end
	if not vim.api.nvim_win_is_valid(state.win) then
		return
	end

	vim.api.nvim_set_current_win(state.win)
	local buf = vim.api.nvim_win_get_buf(state.win)
	local line_count = vim.api.nvim_buf_line_count(buf)
	local line = math.min(state.pos[1], line_count)
	vim.api.nvim_win_set_cursor(state.win, { line, state.pos[2] })
end

---Executes a function and keeps cursor position intact
---@param callback function
---@param bufnr integer
function M.with_restored_cursor(callback, bufnr)
	local old_pos = vim.api.nvim_win_get_cursor(bufnr)

	callback()

	local buf = vim.api.nvim_win_get_buf(bufnr)
	local line_count = vim.api.nvim_buf_line_count(buf)
	if old_pos[1] <= line_count then
		vim.api.nvim_win_set_cursor(bufnr, old_pos)
	end
end

---Executes a function and keeps cursor position intact
---@param old_pos integer[] [row, col]
---@param bufnr integer
function M.move_cursor(old_pos, bufnr)
	local buf = vim.api.nvim_win_get_buf(bufnr)
	local line_count = vim.api.nvim_buf_line_count(buf)
	if old_pos[1] <= line_count then
		vim.api.nvim_win_set_cursor(bufnr, old_pos)
	end
end

return M
