-- lua/plugins/editor/inc-rename.lua
return {
	"smjonas/inc-rename.nvim",
	cmd = "IncRename",
	opts = {
		input_buffer_type = "dressing", -- or nil for cmdline
		preview_empty_name = false,
		show_message = true,
	},
	keys = {
		{
			"<leader>cr",
			function()
				return ":IncRename " .. vim.fn.expand("<cword>")
			end,
			expr = true,
			desc = "Rename (inc-rename)",
		},
	},
	config = function(_, opts)
		require("inc_rename").setup(opts)

		-- Noice integration for better UI
		-- If you're using noice, it will automatically pick up IncRename
	end,
}
