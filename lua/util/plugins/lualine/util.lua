--- Lualine utility functions for formatting and data processing
--- Provides helper functions for environment cleanup, string formatting, and component data
---@class util.plugins.lualine.util
local lualine_util = {}

--- String formatting helper
local fmt = string.format

--- Clean up virtual environment path to extract just the environment name
--- Strips the full path to show only the final directory name
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

--- Convert a displayed string to lowercase for consistent formatting
---@param displayed string The string to format
---@return string lowercase_string The formatted lowercase string
function lualine_util.unified_format(displayed)
	return displayed:lower()
end

--- Takes a list of strings, makes them unique and concatenates them by a separator
--- Optionally limits display to show count when list exceeds limit
---@param list table<string> Array of strings to process
---@param sep string|nil Separator to join strings (default: ", ")
---@param limit number|nil Maximum items to display before showing count (default: 1)
---@return string formatted_string The formatted string representation
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

--- Returns a string formatted by a unique list of methods on the current filetype
--- Queries registered null-ls methods for the current buffer's filetype
---@param method string The method type to query (e.g., "diagnostics", "code_actions")
---@param sep string|nil Separator for joining method names (default: ", ")
---@return string|nil method_list Formatted list of registered methods or nil if unavailable
function lualine_util.get_registered_methods(method, sep)
	local buf_ft = vim.bo.filetype
	local ok, method_service =
		pcall(require, "qvim.lang.null-ls.methodservice." .. method)
	if ok then
		local supported_diagnostics = method_service:list_registered(buf_ft)
		if method == "code_actions" then
			return lualine_util.unique_list_string_format(
				supported_diagnostics,
				sep
			)
		else
			return lualine_util.unique_list_string_format(
				supported_diagnostics,
				sep,
				2
			)
		end
	else
		return nil
	end
end

--- Get a symbol from the icons.signs table with optional modifier
--- Retrieves alphabetic symbols with different styles (box, circle, filled, outline)
---@param letter string Single letter to get symbol for
---@param modifier string|nil Style modifier: "BoxFull", "BoxOutline", "CircleFull", "CircleOutline" or nil for normal
---@return string|nil symbol The retrieved symbol or nil if not found
function lualine_util.get_symbol(letter, modifier)
	local lookup
	if modifier then
		lookup = string.upper(letter) .. modifier
	else
		lookup = string.upper(letter)
	end
	if icons.signs[lookup] then
		return icons.signs[lookup]
	else
		return nil
	end
end

--- Shorten a git branch name to fit within specified length
--- Truncates branch names by splitting on delimiters and preserving as much as possible
---@param branch_name string The full branch name to shorten
---@param max_length number Maximum allowed length for the branch name
---@return string shortened_name The shortened branch name with "..." if truncated
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

--- Pretty path component - shows filename with path relative to project root
--- Creates a function that returns formatted file path for lualine display
---@return function path_function Function that returns the formatted path string
function lualine_util.get_path()
	return function()
		local path = vim.fn.expand("%:p")
		if path == "" then
			return ""
		end
		local root = require("util.root").get()
		-- Make path relative to root
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
