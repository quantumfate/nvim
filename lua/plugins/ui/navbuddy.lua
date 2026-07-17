--- Navbuddy (lazy.nvim spec): LSP symbol tree navigation popup, `gn` to open.

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
			auto_attach = true, -- attaches automatically, no manual attach() needed
		},
		-- _G.mini_icons_mt is a global icon table set up during mini.nvim init.
		icons = _G.mini_icons_mt,
	},
	keys = {
		{ "gn", "<cmd>Navbuddy<cr>", desc = "Navbuddy" },
	},
	--- Patches navic's comment/telescope integration, then starts navbuddy.
	config = function(_, opts)
		local nvim_navic_util = require("util.plugins.navbuddy")
		nvim_navic_util.override_comment()
		nvim_navic_util.override_telescope(require("plugins.lib.snacks-picker").opts)
		require("nvim-navbuddy").setup(opts)
	end,
}
