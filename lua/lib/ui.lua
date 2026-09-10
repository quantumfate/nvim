--- Saving and restoring window/cursor positions around operations.
---@class lib.ui
local M = {}

---@class WindowState
---@field win integer Window handle
---@field pos integer[] Cursor position as [row, col]

--- Captures the current window handle and cursor position.
---@return WindowState win_pos
function M.save_win_and_cursor()
	local win = vim.api.nvim_get_current_win()
	return { win = win, pos = vim.api.nvim_win_get_cursor(win) }
end

--- Restores a saved window/cursor, clamping the row to the buffer's line count.
---@param state WindowState|nil
function M.restore_win_and_cursor(state)
	if not state or not vim.api.nvim_win_is_valid(state.win) then
		return
	end
	vim.api.nvim_set_current_win(state.win)
	local line_count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(state.win))
	vim.api.nvim_win_set_cursor(state.win, { math.min(state.pos[1], line_count), state.pos[2] })
end

return M
