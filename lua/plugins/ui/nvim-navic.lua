return {
	{
		"SmiteshP/nvim-navic",
		dependencies = {
			"neovim/nvim-lspconfig",
			"nvim-mini/mini.nvim",
		},
		event = "User FileOpened",
		opts = {
			icons = _G.mini_icons_mt,
			lsp = {
				auto_attach = true,
				preference = nil,
			},
			highlight = false,
			separator = " > ",
			depth_limit = 0,
			depth_limit_indicator = "..",
			safe_output = true,
			lazy_update_context = false,
			click = false,
			format_text = function(text)
				return text
			end,
		},
	},
	{
		"hasansujon786/nvim-navbuddy",
		dependencies = {
			"neovim/nvim-lspconfig",
			"SmiteshP/nvim-navic",
			"MunifTanjim/nui.nvim",
		},
		opts = {
			lsp = {
				auto_attach = true, -- If set to true, you don't need to manually use attach function
			},
			icons = _G.mini_icons_mt,
		},
		config = function(_, opts)
			local nvim_navic_util = require("util.plugins.nvim-navic")
			nvim_navic_util.override_comment()
			nvim_navic_util.override_telescope()
			require("nvim-navbuddy").setup(opts)
		end,
	},
}
