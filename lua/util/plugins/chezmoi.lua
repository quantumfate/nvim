--- Chezmoi dotfile picker built on the Snacks picker.
---@class util.plugins.chezmoi
local M = {}

--- Opens a Snacks picker of chezmoi-managed files; edits the chosen one with --watch.
--- Snacks is a global from snacks.nvim.
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
