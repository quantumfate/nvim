--- Adapts the harpoon list into Snacks picker items.
---@class util.plugins.harpoon
local M = {}

--- Harpoon marks as picker items ({ text, file, idx }).
---@return { text: string, file: string, idx: integer }[] items
function M.get_items()
	local items = {}
	for i, item in ipairs(require("harpoon"):list().items) do
		items[#items + 1] = { text = item.value, file = item.value, idx = i }
	end
	return items
end

return M
