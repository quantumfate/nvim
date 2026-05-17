return {
	"hasansujon786/nvim-navbuddy",
	dependencies = {
		"neovim/nvim-lspconfig",
		"SmiteshP/nvim-navic",
		"MunifTanjim/nui.nvim",
	},
	cmd = { "Navbuddy" },
	opts = {
		lsp = {
			auto_attach = true, -- If set to true, you don't need to manually use attach function
		},
		icons = _G.mini_icons_mt,
	},
	keys = {
		{ "gn", "<cmd>Navbuddy<cr>", desc = "Navbuddy" },
	},
	config = function(_, opts)
		local nvim_navic_util = require("util.plugins.navbuddy")
		nvim_navic_util.override_comment()
		nvim_navic_util.override_telescope(require("plugins.lib.snacks-picker").opts)
		require("nvim-navbuddy").setup(opts)
	end,
}
