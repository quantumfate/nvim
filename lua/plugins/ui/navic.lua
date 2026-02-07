return {
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
}
