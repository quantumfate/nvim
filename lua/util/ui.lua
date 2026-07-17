--- Saving and restoring window/cursor positions around operations.
---@class util.ui
local M = {}

---@class WindowState
---@field win integer Window handle
---@field pos integer[] Cursor position as [row, col]

--- Captures the current window handle and cursor position.
---@return WindowState win_pos
function M.save_win_and_cursor()
	local win = vim.api.nvim_get_current_win()
	local pos = vim.api.nvim_win_get_cursor(win)
	return { win = win, pos = pos }
end

--- Restores a saved window/cursor, clamping the row to the buffer's line count.
---@param state WindowState|nil
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

--- Runs callback, then restores the window's cursor if its row still exists.
---@param callback function
---@param bufnr integer Window handle (not buffer)
function M.with_restored_cursor(callback, bufnr)
	local old_pos = vim.api.nvim_win_get_cursor(bufnr)

	callback()

	local buf = vim.api.nvim_win_get_buf(bufnr)
	local line_count = vim.api.nvim_buf_line_count(buf)
	if old_pos[1] <= line_count then
		vim.api.nvim_win_set_cursor(bufnr, old_pos)
	end
end

--- Moves the window's cursor to old_pos when the row is within the buffer.
---@param old_pos integer[] Cursor position as [row, col]
---@param bufnr integer Window handle (not buffer)
function M.move_cursor(old_pos, bufnr)
	local buf = vim.api.nvim_win_get_buf(bufnr)
	local line_count = vim.api.nvim_buf_line_count(buf)
	if old_pos[1] <= line_count then
		vim.api.nvim_win_set_cursor(bufnr, old_pos)
	end
end

return M
