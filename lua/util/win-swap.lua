--- Swap current window's buffer with a neighbor's, restricted to regular file buffers.
--- Sidebars (trouble, edgy, neotree, dap, etc.) have non-empty buftype and are skipped.
---@class util.win-swap
local M = {}

---@param buf integer
---@return boolean
local function is_file_buf(buf)
	return vim.bo[buf].buftype == ""
end

--- Swap current window's buffer + cursor with the neighbor in the given direction.
---@param dir "h"|"j"|"k"|"l"
function M.swap(dir)
	local cur_win = vim.api.nvim_get_current_win()
	local target_winnr = vim.fn.winnr(dir)
	if target_winnr == vim.fn.winnr() then
		vim.notify("No split in that direction", vim.log.levels.INFO)
		return
	end
	local target_win = vim.fn.win_getid(target_winnr)

	local cur_buf = vim.api.nvim_win_get_buf(cur_win)
	local target_buf = vim.api.nvim_win_get_buf(target_win)

	if not (is_file_buf(cur_buf) and is_file_buf(target_buf)) then
		vim.notify("Swap aborted: non-file buffer in target", vim.log.levels.WARN)
		return
	end

	local cur_pos = vim.api.nvim_win_get_cursor(cur_win)
	local target_pos = vim.api.nvim_win_get_cursor(target_win)

	vim.api.nvim_win_set_buf(cur_win, target_buf)
	vim.api.nvim_win_set_buf(target_win, cur_buf)

	pcall(vim.api.nvim_win_set_cursor, cur_win, target_pos)
	pcall(vim.api.nvim_win_set_cursor, target_win, cur_pos)
end

return M
