local M = {}

function M.get_items()
	local items = {}
	for i, item in ipairs(require("harpoon"):list().items) do
		items[#items + 1] = { text = item.value, file = item.value, idx = i }
	end
	return items
end

return M
