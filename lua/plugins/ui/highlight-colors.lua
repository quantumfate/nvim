--- Inline color-code highlighting (hex, rgb, Tailwind) as background swatches.

return {
	"brenoprata10/nvim-highlight-colors",
	event = "BufReadPost",
	opts = {
		render = "background",
		virtual_symbol = "●",
		enable_tailwind = true,
	},
}
