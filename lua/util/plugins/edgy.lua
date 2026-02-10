local M = {}

-- Define views and their Trouble panels
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

-- Extract mode names from commands + common LSP modes
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

vim.g.edgy_current_view = nil

function M.has_lsp_and_is_file()
	local buf = vim.api.nvim_get_current_buf()
	local has_lsp = #vim.lsp.get_clients({ bufnr = buf }) > 0
	local is_file = vim.bo[buf].buftype == ""
	return has_lsp and is_file
end

function M.close_all()
	for _, mode in ipairs(M.modes) do
		pcall(vim.cmd, "Trouble close " .. mode)
	end
	vim.g.edgy_current_view = nil
end

--- Open an edgy view of the currently focused window. Closes all splits.
---@param name string Name of the view
---@param ... any Options parsed to view functions that implement one
function M.open_view(name, ...)
	local view = M.views[name]
	if not view then
		vim.notify("Unknown edgy view: " .. name, vim.log.levels.ERROR)
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

function M.toggle_view(name)
	if not M.has_lsp_and_is_file() then
		vim.notify("No LSP attached to this buffer", vim.log.levels.WARN)
		return
	end
	if vim.g.edgy_current_view == name then
		M.close_all()
	else
		M.open_view(name)
	end
end

return M
