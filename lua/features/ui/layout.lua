--- Workspace layout state management: snapshot and restore window topologies,
--- viewports, and presets across workflows (e.g. code <-> debug <-> review).
---@class ui.layout
local M = {}

--- Saved layout snapshots by name.
---@type table<string, ui.LayoutSnapshot>
M.snapshots = {}

---@class ui.WindowSnapshot
---@field win integer
---@field buf integer
---@field file string
---@field cursor integer[]
---@field width integer
---@field height integer
---@field slot? string

---@class ui.LayoutSnapshot
---@field tab integer
---@field cur_win integer
---@field windows ui.WindowSnapshot[]
---@field win_view table<integer, table>
---@field sidebar_source? string

--- Captures a complete snapshot of the current window configuration.
---@param name string Snapshot identifier (e.g. "code", "before_debug")
---@return ui.LayoutSnapshot
function M.snapshot(name)
	local tab = vim.api.nvim_get_current_tabpage()
	local cur_win = vim.api.nvim_get_current_win()
	local windows = {}
	local win_view = {}

	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		if vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			table.insert(windows, {
				win = win,
				buf = buf,
				file = vim.api.nvim_buf_get_name(buf),
				cursor = vim.api.nvim_win_get_cursor(win),
				width = vim.api.nvim_win_get_width(win),
				height = vim.api.nvim_win_get_height(win),
				slot = vim.w[win].workspace_slot,
			})
			pcall(function()
				win_view[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
			end)
		end
	end

	local sidebar = require("features.ui.sidebar")
	local snapshot = {
		tab = tab,
		cur_win = cur_win,
		windows = windows,
		win_view = win_view,
		sidebar_source = sidebar.active_source(),
	}

	M.snapshots[name] = snapshot
	return snapshot
end

--- Restores a previously captured layout snapshot.
---@param name string Snapshot identifier
---@return boolean restored
function M.restore(name)
	local snap = M.snapshots[name]
	if not snap then
		return false
	end

	-- Restore windows that are still valid
	for _, ws in ipairs(snap.windows) do
		if vim.api.nvim_win_is_valid(ws.win) then
			if vim.api.nvim_buf_is_valid(ws.buf) then
				pcall(vim.api.nvim_win_set_buf, ws.win, ws.buf)
			end
			pcall(vim.api.nvim_win_set_cursor, ws.win, ws.cursor)
			if snap.win_view[ws.win] then
				pcall(vim.api.nvim_win_call, ws.win, function()
					vim.fn.winrestview(snap.win_view[ws.win])
				end)
			end
			if ws.slot then
				vim.w[ws.win].workspace_slot = ws.slot
			end
		end
	end

	if vim.api.nvim_win_is_valid(snap.cur_win) then
		pcall(vim.api.nvim_set_current_win, snap.cur_win)
	end

	-- Restore sidebar state if known
	if snap.sidebar_source then
		pcall(require("features.ui.sidebar").switch, snap.sidebar_source)
	end

	return true
end

--- Enters the interactive debugging layout, snapshotting code state.
function M.to_debug()
	M.snapshot("code")
	-- Open debug dock panel
	pcall(function()
		require("features.workspace").dock().open("debug")
	end)
end

--- Returns from debugging layout, restoring previous code state.
function M.to_code()
	pcall(function()
		require("features.workspace").dock().close()
	end)
	M.restore("code")
end

return M
