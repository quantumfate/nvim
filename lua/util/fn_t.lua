--- Table helpers: search, transform, invert, and count operations.
---@class util.fn_t
---@alias Table util.fn_t
local Table = {}

--- Joins table elements into a single delimited string.
---@param t table
---@param d string Delimiter between elements
---@return string joined_string
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

--- Returns the first entry for which the predicate is true, or nil.
---@param t table
---@param predicate function
---@return any|nil entry
function Table.find_first(t, predicate)
	for _, entry in pairs(t) do
		if predicate(entry) then
			return entry
		end
	end
	return nil
end

--- True if the predicate holds for any entry.
---@param t table
---@param predicate fun(entry: any):boolean
---@return boolean has_match
function Table.any(t, predicate)
	for _, entry in pairs(t) do
		if predicate(entry) then
			return true
		end
	end
	return false
end

--- Returns a new table with keys and values swapped.
---@param t table
---@return table inverted_table
function Table.invert_table(t)
	local inverted_t = {}
	for key, value in pairs(t) do
		inverted_t[value] = key
	end
	return inverted_t
end

--- Transforms every key (do_keys) or value of a table via transform_fn.
---@param tbl table
---@param transform_fn function
---@param do_keys boolean Transform keys when true, values when false
---@return table transformed_table
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

--- True if the table contains the given key, optionally searching nested tables.
---@param t table
---@param find any Key to search for
---@param recurse boolean|nil
---@return boolean has_key
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

--- True if the table contains the given value, optionally searching nested tables.
---@param t table
---@param find any Value to search for
---@param recurse boolean|nil
---@return boolean has_value
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

--- Counts all key-value pairs, not just the array part.
---@param t table
---@return integer count
function Table.length(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

--- True if the predicate holds for at least one entry.
---@param t table
---@param predicate function
---@return boolean contains
function Table.contains(t, predicate)
	return Table.find_first(t, predicate) ~= nil
end

return Table
