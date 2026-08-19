---@class util.string_f
local string_f = {}
local function __init_array(s)
	local arr = {}
	for i = 1, #s, 1 do
		arr[i] = 0
	end
	return arr
end

--- Returns the longest common subpath of two paths
---@param path_one string
---@param path_two string
---@return string, integer
function string_f.commonsub(path_one, path_two)
	-- https://www.geeksforgeeks.org/dsa/longest-common-substring-dp-29/
	local prev = __init_array(path_one)
	local substring_length = 0
	local end_pos = 0

	for i = 1, #path_one, 1 do
		local curr = __init_array(path_two)
		for j = 1, #path_two, 1 do
			if path_one[i] == path_two[j] then
				curr[j] = (j > 1 and prev[j - 1] or 0) + 1
				if curr[j] > substring_length then
					substring_length = curr[j]
					end_pos = i
				end
			end
		end
		prev = curr
	end

	local longest_substring = path_one:sub(end_pos - substring_length + 1, end_pos)
	return longest_substring, substring_length
end

return string_f
