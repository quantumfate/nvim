--- Table utility functions for advanced table operations and manipulations
--- Provides comprehensive set of functions for searching, transforming, and analyzing tables
---@class util.fn_t
---@alias Table util.fn_t
local Table = {}

local log = require("qvim.log").qvim
local fmt = string.format

--- Join a table to a string with a delimiter
--- Concatenates table elements into a single string separated by delimiter
---@param t table Table to join into string
---@param d string Delimiter to use between elements
---@return string joined_string The concatenated string result
function Table.join(t, d)
	local count = #t
	if count == 1 then
		return t[1]
	end
	local s = ""
	for i, value in pairs(t) do
		s = i < count and s + value + d or s + value
	end
	return s
end

--- Find the first entry for which the predicate returns true
--- Iterates through table until predicate function returns true
---@param t table Table to search through
---@param predicate function Function called for each entry of t
---@return any|nil entry Entry for which the predicate returned true or nil
function Table.find_first(t, predicate)
	for _, entry in pairs(t) do
		if predicate(entry) then
			return entry
		end
	end
	return nil
end

--- Checks if any entry in a table satisfies a predicate
--- Returns true as soon as any element matches the predicate condition
---@param t table Table to check
---@param predicate fun(entry: any):boolean Function to test each entry
---@return boolean has_match True if any entry satisfies the predicate
function Table.any(t, predicate)
	for _, entry in pairs(t) do
		if predicate(entry) then
			return true
		end
	end
	return false
end

--- Inverts the key and value pairs of the given table
--- Creates new table where original values become keys and original keys become values
---@param t table Table to invert
---@return table inverted_table New table with inverted key-value pairs
function Table.invert_table(t)
	local inverted_t = {}
	for key, value in pairs(t) do
		inverted_t[value] = key
	end
	return inverted_t
end

--- Transforms table keys or values using a transformation function
--- Applies transformation to either keys or values based on do_keys parameter
---@param tbl table The table to be transformed
---@param transform_fn function Function to transform each key or value
---@param do_keys boolean If true, transform keys; if false, transform values
---@return table transformed_table New table with transformed elements
function Table.transform_to_table(tbl, transform_fn, do_keys)
	local transformed = {}
	for k, v in pairs(tbl) do
		if do_keys then
			transformed[#transformed + 1] = transform_fn(k)
		else
			transformed[k] = transform_fn(v)
		end
	end
	return transformed
end

--- Checks if a table contains a specific key
--- Optionally searches recursively through nested tables
---@param t table Table to search in
---@param find any Key to search for
---@param recurse boolean|nil Whether to search recursively in nested tables
---@return boolean has_key True if key is found in table
function Table.has_any_key(t, find, recurse)
	if recurse == nil then
		recurse = false
	end
	for key, _ in pairs(t) do
		if key == find then
			return true
		end
		if type(t[key]) == "table" and recurse then
			if Table.has_any_key(t[key], find, recurse) then
				return true
			end
		end
	end
	return false
end

--- Checks if a table contains a specific value
--- Optionally searches recursively through nested tables
---@param t table Table to search in
---@param find any Value to search for
---@param recurse boolean|nil Whether to search recursively in nested tables
---@return boolean has_value True if value is found in table
function Table.has_any_value(t, find, recurse)
	if recurse == nil then
		recurse = false
	end
	for _, entry in pairs(t) do
		if entry == find then
			return true
		end
		if type(entry) == "table" and recurse then
			if Table.has_any_value(entry, find, recurse) then
				return true
			end
		end
	end
	return false
end

--- Counts the elements in a table regardless of their type
--- Counts all key-value pairs in the table, not just array elements
---@param t table Table to count elements in
---@return integer count Total number of elements in the table
function Table.length(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

--- Check if the predicate returns true for at least one entry of the table
--- Convenience function that uses find_first to check for existence
---@param t table The table to check
---@param predicate function The function called for each entry of t
---@return boolean contains True if predicate returned true at least once, false otherwise
function Table.contains(t, predicate)
	return Table.find_first(t, predicate) ~= nil
end

return Table
