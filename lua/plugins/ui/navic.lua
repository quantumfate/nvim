--- Navic (lazy.nvim spec): LSP breadcrumb of the symbol path, shown in the winbar.

return {
	"SmiteshP/nvim-navic",
	dependencies = {
		"neovim/nvim-lspconfig",
		"nvim-mini/mini.nvim",
	},
	event = "User FileOpened",
	opts = {
		-- _G.mini_icons_mt is a global icon table set up during mini.nvim init.
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
		--- Passes breadcrumb text through unchanged.
		format_text = function(text)
			return text
		end,
	},
}
