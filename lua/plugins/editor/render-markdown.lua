--- render-markdown.nvim: in-buffer rendering of markdown (and vimwiki/Avante) files.
return {
	"MeanderingProgrammer/render-markdown.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" },
	-- Parse vimwiki buffers with the markdown parser before returning the render config.
	opts = function()
		vim.treesitter.language.register("markdown", "vimwiki")
		return {
			file_types = { "markdown", "vimwiki", "Avante" },
			completions = { lsp = { enabled = true } },
		}
	end,
	ft = { "markdown", "Avante" },
}
