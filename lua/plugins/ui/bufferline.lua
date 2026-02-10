return {
	"akinsho/bufferline.nvim",
	event = "BufEnter",
	dependencies = { "nvim-tree/nvim-web-devicons", "nvim-mini/mini.nvim" },
	config = function(_, opts)
		opts.highlights = require("catppuccin.special.bufferline").get_theme()
		require("bufferline").setup(opts)
	end,
	keys = {
		{
			"<leader>bda",
			function()
				Snacks.bufdelete.all()
			end,
			desc = "all buffers",
		},
		{
			"<leader>bdt",
			function()
				Snacks.bufdelete.delete()
			end,
			desc = "current buffer",
		},
		{
			"<leader>bdo",
			function()
				Snacks.bufdelete.other()
			end,
			desc = "other buffers",
		},
		{
			"<leader>br",
			function()
				Snacks.explorer.reveal()
			end,
			desc = "reveal in explorer",
		},
		{
			"<leader>bp",
			function()
				Snacks.picker.buffers()
			end,
			desc = "Buffers",
		},
	},
	opts = {
		options = {
            -- stylua: ignore
            close_command = function(n) Snacks.bufdelete(n) end,
            -- stylua: ignore
            right_mouse_command = function(n) Snacks.bufdelete(n) end,
			diagnostics = "nvim_lsp",
			always_show_bufferline = false,
			diagnostics_indicator = function(_, _, diag)
				local icons = icons.diagnostics
				local ret = (diag.error and icons.Error .. diag.error .. " " or "")
					.. (diag.warning and icons.Warning .. diag.warning or "")
				return vim.trim(ret)
			end,
			offsets = {
				{
					filetype = "neo-tree",
					text = "Neo-tree",
					highlight = "Directory",
					text_align = "left",
				},
				{
					filetype = "snacks_layout_box",
				},
			},
			get_element_icon = function(opts)
                -- stylua: ignore
                return require("mini.icons").get("filetype", opts.filetype)
			end,
		},
	},
}
