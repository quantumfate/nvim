--- Navbuddy (lazy.nvim spec): LSP symbol tree navigation, `<leader>cn` to open.
---
--- Opened over the workspace's `aux` pane rather than the centre of the screen, so it
--- stops covering the code it is describing. See features/navbuddy.open_in_aux.

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
		{
			"<leader>cn",
			function()
				require("features.navbuddy").open_in_aux()
			end,
			desc = "Navbuddy (over the aux pane)",
		},
	},
	--- Patches navic's comment/telescope integration, then starts navbuddy.
	config = function(_, opts)
		local nvim_navic_util = require("features.navbuddy")
		nvim_navic_util.override_comment()
		nvim_navic_util.override_telescope(require("plugins.lib.snacks-picker").opts)
		require("nvim-navbuddy").setup(opts)
	end,
}
