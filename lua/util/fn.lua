--- String and table helpers used across the config.
---@class util.fn
local M = {}

--- Replaces hyphens with underscores; passes non-strings through unchanged.
---@param val string|nil
---@return string|nil normalized_val
function M.normalize(val)
	if val and type(val) == "string" then
		if not string.find(val, "-") then
			return val
		end
		return val:gsub("-", "_")
	end
	return val
end

--- Recursively copies a table, cloning nested tables.
---@param t table
---@return table copy
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

--- True if the string is nil or empty.
---@param s string
---@return boolean is_empty
function M.isempty(s)
	return s == nil or s == ""
end

--- Reads a buffer option on the current buffer, returning nil on error.
---@param opt string
---@return any|nil option_value
function M.get_buf_option(opt)
	local status_ok, buf_option = pcall(vim.api.nvim_buf_get_option, 0, opt)
	if not status_ok then
		return nil
	else
		return buf_option
	end
end

--- Generates a random version-4 UUID string.
---@return string uuid
---@return integer substitutions gsub replacement count
function M.gen_uuid()
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	return template:gsub("[xy]", function(c)
		local v = math.random(0, 15)
		if c == "y" then
			v = (v & 0x3) | 0x8 -- variant bits: 8..b
		end
		return string.format("%x", v)
	end)
end

return M
