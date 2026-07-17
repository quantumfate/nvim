--- Buffer tabline with diagnostics and buffer-management keymaps (lazy.nvim spec).

---@class BufferlineConfig
---@field options table Buffer display and interaction options
---@field highlights? table Theme-specific highlight overrides

return {
	"akinsho/bufferline.nvim",
	enabled = false,
	event = "User FileOpened",
	dependencies = { "nvim-tree/nvim-web-devicons", "nvim-mini/mini.nvim" },
	--- Injects the catppuccin highlight theme before starting bufferline.
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
			-- Snacks is a global plugin API providing buffer deletion.
			close_command = function(n)
				Snacks.bufdelete(n)
			end,
			right_mouse_command = function(n)
				Snacks.bufdelete(n)
			end,
			diagnostics = "nvim_lsp",
			always_show_bufferline = false,
			--- Renders the error/warning counts on each buffer.
			diagnostics_indicator = function(_, _, diag)
				-- `icons` is a global table set up elsewhere in the config.
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
			--- Resolves each buffer's icon from mini.icons by filetype.
			get_element_icon = function(opts)
				return require("mini.icons").get("filetype", opts.filetype)
			end,
		},
	},
}
