return {
	-- Make sure to set this up properly if you have lazy=true
	"MeanderingProgrammer/render-markdown.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" },
	opts = function()
		vim.treesitter.language.register("markdown", "vimwiki")
		return {
			file_types = { "markdown", "vimwiki", "Avante" },
			completions = { lsp = { enabled = true } },
		}
	end,
	ft = { "markdown", "Avante" },
}
