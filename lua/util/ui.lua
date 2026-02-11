--- UI utility module for window and cursor management
--- Provides functions for saving/restoring cursor positions and window states
---@class util.ui
local M = {}

--- Window and cursor position state
---@class WindowState
---@field win integer Window handle
---@field pos integer[] Cursor position as [row, col]

--- Save the current window's cursor position
--- Captures both window handle and cursor coordinates for later restoration
---@return WindowState win_pos Table containing window handle and cursor position
function M.save_win_and_cursor()
	local win = vim.api.nvim_get_current_win()
	local pos = vim.api.nvim_win_get_cursor(win)
	return { win = win, pos = pos }
end

--- Restore cursor to a previously saved window position
--- Validates window and adjusts cursor position if buffer has changed
---@param state WindowState|nil Previously saved state from save_win_and_cursor
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

--- Execute a function while preserving cursor position
--- Automatically saves and restores cursor position around callback execution
---@param callback function Function to execute
---@param bufnr integer Window handle to preserve cursor position for
function M.with_restored_cursor(callback, bufnr)
	local old_pos = vim.api.nvim_win_get_cursor(bufnr)

	callback()

	local buf = vim.api.nvim_win_get_buf(bufnr)
	local line_count = vim.api.nvim_buf_line_count(buf)
	if old_pos[1] <= line_count then
		vim.api.nvim_win_set_cursor(bufnr, old_pos)
	end
end

--- Move cursor to a specific position with bounds checking
--- Ensures cursor position doesn't exceed buffer line count
---@param old_pos integer[] Cursor position as [row, col]
---@param bufnr integer Window handle to move cursor in
function M.move_cursor(old_pos, bufnr)
	local buf = vim.api.nvim_win_get_buf(bufnr)
	local line_count = vim.api.nvim_buf_line_count(buf)
	if old_pos[1] <= line_count then
		vim.api.nvim_win_set_cursor(bufnr, old_pos)
	end
end

return M
