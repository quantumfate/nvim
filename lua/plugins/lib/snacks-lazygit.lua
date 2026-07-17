-- snacks.lazygit spec: opens lazygit in a floating window (defaults; keymap only).

return {
	"folke/snacks.nvim",
	---@type snacks.Config
	opts = {
		lazygit = {}, -- defaults
	},
	keys = {
		-- External: Snacks global provides the lazygit launcher.
		{
			"<leader>ig",
			function()
				Snacks.lazygit()
			end,
			desc = "lazygit",
		},
	},
}
