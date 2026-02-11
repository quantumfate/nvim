--- Edgy utility module for managing Trouble panel views
--- Provides functionality to open, close, and toggle different diagnostic and LSP views
---@class util.plugins.edgy
local M = {}

--- View definitions mapping view names to their corresponding Trouble commands
--- Each view can contain multiple commands that will be executed in sequence
---@type table<string, string[]|function>
M.views = {
	diagnostics = {
		"Trouble diagnostics focus=false",
		"Trouble symbols focus=false",
	},
	lsp = {
		"Trouble lsp focus=false",
		"Trouble symbols focus=false",
	},
	focus = {
		"Trouble symbols focus=false",
	},
}

--- Available Trouble modes for closing operations
--- Includes both diagnostic modes and LSP-specific modes
---@type string[]
M.modes = {
	"diagnostics",
	"symbols",
	"lsp",
	"lsp_references",
	"lsp_definitions",
	"lsp_type_definitions",
	"lsp_implementations",
	"lsp_incoming_calls",
	"lsp_outgoing_calls",
	"qflist",
	"loclist",
}

--- Global variable to track the currently active edgy view
vim.g.edgy_current_view = nil

--- Check if the current buffer has LSP attached and is a regular file
--- Used to determine if LSP-related views should be available
---@return boolean has_lsp_and_file True if buffer has LSP client and is a file buffer
function M.has_lsp_and_is_file()
	local buf = vim.api.nvim_get_current_buf()
	local has_lsp = #vim.lsp.get_clients({ bufnr = buf }) > 0
	local is_file = vim.bo[buf].buftype == ""
	return has_lsp and is_file
end

--- Close all Trouble modes and reset the current view state
--- Safely closes each mode using pcall to prevent errors
function M.close_all()
	for _, mode in ipairs(M.modes) do
		pcall(vim.cmd, "Trouble close " .. mode)
	end
	vim.g.edgy_current_view = nil
end

--- Open a specific edgy view, closing splits and other views first
--- Executes the view's commands or function to display the requested panels
---@param name string The name of the view to open (must exist in M.views)
---@param ... any Additional options passed to view functions
function M.open_view(name, ...)
	local view = M.views[name]
	if not view then
		Snacks.notify.error("Unknown edgy view: " .. name)
		return
	end
	if #vim.api.nvim_tabpage_list_wins(0) > 1 then
		vim.cmd("only")
	end
	M.close_all()
	if type(view) == "function" then
		view(...)
	elseif type(view) == "table" then
		for _, cmd in ipairs(view) do
			vim.cmd(cmd)
		end
	end
	vim.g.edgy_current_view = name
end

--- Toggle a specific edgy view on or off
--- Opens the view if not currently active, closes all views if already active
---@param name string The name of the view to toggle
function M.toggle_view(name)
	if not M.has_lsp_and_is_file() then
		Snacks.notify.error("No LSP attached to this buffer")
		return
	end
	if vim.g.edgy_current_view == name then
		M.close_all()
	else
		M.open_view(name)
	end
end

return M
