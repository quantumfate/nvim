--- neogen: generate annotation/docstring skeletons (file, class, function, type) via LuaSnip.
return {
	"danymat/neogen",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"L3MON4D3/LuaSnip",
	},
	opts = {
		snippet_engine = "luasnip",
	},
	keys = {
		{
			"<leader>nF",
			function()
				require("neogen").generate({ type = "File" })
			end,
			desc = "Generate File Annotations",
		},
		{
			"<leader>nc",
			function()
				require("neogen").generate({ type = "Class" })
			end,
			desc = "Generate Class Annotations",
		},
		{
			"<leader>nf",
			function()
				require("neogen").generate({ type = "func" })
			end,
			desc = "Generate Function Annotations",
		},
		{
			"<leader>nt",
			function()
				require("neogen").generate({ type = "type" })
			end,
			desc = "Generate Type Annotations",
		},
	},
}
