local M = {}

M.pick_chezmoi = function()
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
