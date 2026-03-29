return {
	"folke/snacks.nvim",
	---@type snacks.Config
	opts = {
		lazygit = {
			-- your lazygit configuration comes here
			-- or leave it empty to use the default settings
			-- refer to the configuration section below
		},
	},
	keys = {
		{
			"<leader>pg",
			function()
				Snacks.lazygit()
			end,
			desc = "lazygit",
		},
	},
}
