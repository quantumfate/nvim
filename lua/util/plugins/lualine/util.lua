--- Formatting and data helpers for lualine components.
---@class util.plugins.lualine.util
local lualine_util = {}

--- Reduces a virtualenv path to its final directory (the env name).
---@param venv string Full path to virtual environment
---@return string cleaned_name The environment name without path
function lualine_util.env_cleanup(venv)
	if string.find(venv, "/") then
		local final_venv = venv
		for w in venv:gmatch("([^/]+)") do
			final_venv = w
		end
		venv = final_venv
	end
	return venv
end

--- Lowercases a string for consistent display.
---@param displayed string The string to format
---@return string lowercase_string
function lualine_util.unified_format(displayed)
	return displayed:lower()
end

--- Joins a list's unique items, collapsing to "first +N" once it exceeds `limit`.
---@param list table<string> Array of strings to process
---@param sep string|nil Separator (default: ", ")
---@param limit number|nil Items shown before collapsing to a count (default: 1)
---@return string formatted_string
function lualine_util.unique_list_string_format(list, sep, limit)
	sep = sep or ", "
	limit = limit or 1
	local unique_list = {}
	for _, item in pairs(list) do
		if not vim.tbl_contains(unique_list, item) then
			table.insert(unique_list, item)
		end
	end
	if limit > 0 and #unique_list > limit then
		return unique_list[1] .. " +" .. tostring(#unique_list - 1)
	elseif #unique_list > 1 then
		return table.concat(unique_list, sep)
	else
		return unique_list[1] or ""
	end
end

--- Formats the null-ls methods registered for the current buffer's filetype.
---@param method string Method type to query (e.g. "diagnostics", "code_actions")
---@param sep string|nil Separator (default: ", ")
---@return string|nil method_list nil when the method service is unavailable
function lualine_util.get_registered_methods(method, sep)
	local buf_ft = vim.bo.filetype
	local ok, method_service = pcall(require, "qvim.lang.null-ls.methodservice." .. method)
	if ok then
		local supported_diagnostics = method_service:list_registered(buf_ft)
		if method == "code_actions" then
			return lualine_util.unique_list_string_format(supported_diagnostics, sep)
		else
			return lualine_util.unique_list_string_format(supported_diagnostics, sep, 2)
		end
	else
		return nil
	end
end

--- Looks up a letter's glyph in the global icon table, in an optional style.
---@param letter string Single letter
---@param modifier string|nil "BoxFull"|"BoxOutline"|"CircleFull"|"CircleOutline"|nil
---@return string|nil symbol
function lualine_util.get_symbol(letter, modifier)
	local lookup
	if modifier then
		lookup = string.upper(letter) .. modifier
	else
		lookup = string.upper(letter)
	end
	-- icons: _G.icons, seeded in config/init.lua.
	if icons.signs[lookup] then
		return icons.signs[lookup]
	else
		return nil
	end
end

--- Shortens a branch name to `max_length`, splitting on -/ and keeping whole segments.
---@param branch_name string
---@param max_length number
---@return string shortened_name Ends with "..." when truncated
function lualine_util.shorten_branch_name(branch_name, max_length)
	if #branch_name <= max_length then
		return branch_name
	end

	local parts = {}
	for part in string.gmatch(branch_name, "([^-%/]+)") do
		table.insert(parts, part)
	end

	if #parts == 1 then
		return branch_name:sub(1, max_length) .. "..."
	end

	local new_branch_name = ""
	for i, part in ipairs(parts) do
		if #new_branch_name + #part > max_length then
			break
		end
		new_branch_name = new_branch_name .. (i > 1 and "-" or "") .. part
	end

	return new_branch_name .. "..."
end

--- Returns a lualine component: the file path relative to project root, with a
--- modified marker.
---@return function path_function
function lualine_util.get_path()
	return function()
		local path = vim.fn.expand("%:p")
		if path == "" then
			return ""
		end
		local root = require("util.root").get()
		if path:find(root, 1, true) == 1 then
			path = path:sub(#root + 2)
		end
		local filename = vim.fn.fnamemodify(path, ":t")
		local dir = vim.fn.fnamemodify(path, ":h")
		if dir == "." then
			dir = ""
		else
			dir = dir .. "/"
		end

		if vim.bo.modified then
			filename = filename .. " ●"
		end
		return dir .. filename
	end
end

return lualine_util
