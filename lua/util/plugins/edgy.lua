--- Edgy utility module for managing Trouble panel views. Provides functionality to open, close
--- and toggle different diagnostic and LSP views. Also manages a history of views internally.
---@class util.plugins.edgy
local M = {}

local internal = {}

--[[
--
-- Configuration
--
--]]

-- TODO: currently diagnostics view shows diagnostics of the entire directory/project
--TODO: implement per buffer diagnostics

--- View definitions mapping view names to their corresponding Trouble commands
--- Each view can contain multiple commands that will be executed in sequence
---@type table<string, string[]>
internal.views = {
	diagnostics = {
		"Trouble diagnostics focus=false open_no_results=true",
		"Trouble symbols focus=false open_no_results=true",
	},
	lsp = { "Trouble lsp focus=false open_no_results=true", "Trouble symbols focus=false open_no_results=true" },
	focus = { "Trouble symbols focus=false open_no_results=true" },
	debug = { "DapViewOpen" },
}

--- Defines close action commands for a plugin
---@type table<string, string|function>
internal.generic_close = {
	dap_view = "DapViewClose",
	neo_tree = "Neotree close",
}

--- Strings to be concatenated with "Trouble close"
---@type table<string[]>
internal.trouble_modes = {
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

--[[
--
-- States
--
--]]

local state = {
	current = nil, ---@type string?
	prev = nil, ---@type string?
}

local function push_view(name)
	state.current = name
end

local function pop_view()
	state.prev = state.current
	state.current = nil
end

--[[
--
-- Predicates
--
--]]

--- Check if the current buffer has LSP attached and is a regular file
--- Used to determine if LSP-related views should be available
---@return boolean has_lsp_and_file True if buffer has LSP client and is a file buffer
function internal.has_lsp_and_is_file()
	local buf = vim.api.nvim_get_current_buf()
	local has_lsp = #vim.lsp.get_clients({ bufnr = buf }) > 0
	local is_file = vim.bo[buf].buftype == ""
	return has_lsp and is_file
end

--[[
--
-- Core
--
--]]

local function exec(cmd)
	pcall(vim.api.nvim_command, cmd)
end

local function do_close_all()
	for _, mode in ipairs(internal.trouble_modes) do
		exec("Trouble close " .. mode)
	end
	for _, action in pairs(internal.generic_close) do
		if type(action) == "string" then
			exec(action)
		end
		if type(action) == "function" then
			pcall(action)
		end
	end
end

local function do_open(name)
	local view = internal.views[name]
	if not view then
		Snacks.notify.error("Unknown edgy view: " .. name)
		return false
	end
	if #vim.api.nvim_tabpage_list_wins(0) > 1 then
		exec("only")
	end
	for _, cmd in ipairs(view) do
		exec(cmd)
	end
	return true
end

--[[
--
-- API
--
--]]

---Returns the view saved as current view
---@return string
function M.get_current_view()
	return state.current
end

---Returns the view saved as previous view
---@return string
function M.get_prev_view()
	return state.prev
end

--- Opens a view and stores it as current view
---@param name string on of debug|diagnostics|lsp|focus
---@param idempotent boolean? skips opening the view if it's already opened
---@return string? closed the view that was closed for the newly opened view
function M.open_view(name, idempotent)
	if idempotent then
		if state.current == name then
			return
		end
	end
	local closed = M.close_all()
	local ok = do_open(name)
	if ok then
		push_view(name)
	end
	return closed
end

--- Close all views
---@return string? prev the name of the closed view
function M.close_all()
	do_close_all()
	pop_view()
	return M.get_prev_view()
end

--- Restores the previously stored view without saving the current view to the history
function M.restore_prev_view()
	local target = state.prev
	if target then
		M.open_view(target)
	else
		-- still update reference and close regardless
		do_close_all()
		pop_view()
	end
end

--- Toggles the active view, closing everything else
---@param name string on of debug|diagnostics|lsp|focus
function M.toggle_view(name)
	if not internal.has_lsp_and_is_file() then
		Snacks.notify.error("No LSP attached to this buffer")
		return
	end
	if state.current == name then
		do_close_all()
		pop_view()
	else
		M.open_view(name)
	end
end

return M
