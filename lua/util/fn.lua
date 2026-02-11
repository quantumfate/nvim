--- General utility functions for string manipulation and data operations
--- Provides commonly used helper functions for various data transformations
---@class util.fn
local M = {}

--- Replaces hyphens with underscores in a string
--- Normalizes string format for consistent naming conventions
---@param val string|nil The string value to normalize
---@return string|nil normalized_val The normalized string or original value if not a string
function M.normalize(val)
	if val and type(val) == "string" then
		if not string.find(val, "-") then
			return val
		end
		return val:gsub("-", "_")
	end
	return val
end

--- Recursively creates a shallow copy of a given table
--- Creates a new table with copied values, recursively handling nested tables
---@param t table The table to copy
---@return table copy A shallow copy of the input table
function M.shallow_table_copy(t)
	local copy = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			copy[k] = M.shallow_table_copy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

--- Checks if a string is empty or nil
--- Utility function for string validation
---@param s string The string to check
---@return boolean is_empty True if string is nil or empty, false otherwise
function M.isempty(s)
	return s == nil or s == ""
end

--- Safely get a buffer option with error handling
--- Wraps vim.api.nvim_buf_get_option in pcall for safe access
---@param opt string The buffer option name to retrieve
---@return any|nil option_value The buffer option value or nil if error occurred
function M.get_buf_option(opt)
	local status_ok, buf_option = pcall(vim.api.nvim_buf_get_option, 0, opt)
	if not status_ok then
		return nil
	else
		return buf_option
	end
end

--- Generate a random UUID string
--- Creates a version 4 UUID following the standard format
---@return string uuid A randomly generated UUID string
function M.gen_uuid()
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	return template:gsub("[xy]", function(c)
		local v = math.random(0, 15)
		if c == "y" then
			v = (v & 0x3) | 0x8 -- 8..b for variant
		end
		return string.format("%x", v)
	end)
end

return M
