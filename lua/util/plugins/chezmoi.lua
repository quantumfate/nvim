--- Chezmoi utility module for dotfile management integration
--- Provides functions for picking and editing chezmoi-managed files
---@class util.plugins.chezmoi
local M = {}

--- Open a picker to select and edit chezmoi-managed files
--- Lists all chezmoi files and opens selected file in edit mode with watch
function M.pick_chezmoi()
	local results = require("chezmoi.commands").list({
		args = {
			"--path-style",
			"absolute",
			"--include",
			"files",
			"--exclude",
			"externals",
		},
	})
	local items = {}

	for _, czFile in ipairs(results) do
		table.insert(items, {
			text = czFile,
			file = czFile,
		})
	end

	local opts = {
		items = items,
		confirm = function(picker, item)
			picker:close()
			require("chezmoi.commands").edit({
				targets = { item.text },
				args = { "--watch" },
			})
		end,
	}
	Snacks.picker.pick(opts)
end

return M
