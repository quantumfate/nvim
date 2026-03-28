return {
	"danymat/neogen",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	config = function()
		local neogen = require("neogen")

		neogen.setup({
			snippet_engine = "luasnip",
		})

		require("which-key").add({
			{
				mode = { "n" },
				{
					"<leader>nF",
					function()
						neogen.generate({ type = "File" })
					end,
					desc = "Generate File Annotations",
				},
				{
					"<leader>nc",
					function()
						neogen.generate({ type = "Class" })
					end,
					desc = "Generate Class Annotations",
				},
				{
					"<leader>nf",
					function()
						neogen.generate({ type = "func" })
					end,
					desc = "Generate Function Annotations",
				},
				{
					"<leader>nt",
					function()
						neogen.generate({ type = "type" })
					end,
					desc = "Generate Type Annotations",
				},
			},
		})
	end,
	-- Uncomment next line if you want to follow only stable versions
	-- version = "*"
}
