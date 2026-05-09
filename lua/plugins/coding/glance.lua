return {
	"rmagatti/goto-preview",
	event = "BufEnter",
	dependencies = { "rmagatti/logger.nvim" },
	opts = {
		width = 120, -- Width of the floating window
		height = 25, -- Height of the floating window
		border = { "↖", "─", "┐", "│", "┘", "─", "└", "│" }, -- Border characters of the floating window
		default_mappings = false, -- Bind default mappings
		debug = false, -- Print debug information
		opacity = nil, -- 0-100 opacity level of the floating window where 100 is fully transparent.
		resizing_mappings = false, -- Binds arrow keys to resizing the floating window.
		post_open_hook = nil, -- A function taking two arguments, a buffer and a window to be ran as a hook.
		post_close_hook = nil, -- A function taking two arguments, a buffer and a window to be ran as a hook.
		references = { -- Configure the telescope UI for slowing the references cycling window.
			provider = "snacks", -- telescope|fzf_lua|snacks|mini_pick|default
			telescope = require("telescope.themes").get_dropdown({ hide_preview = false }),
		},
		-- These two configs can also be passed down to the goto-preview definition and implementation calls for one off "peak" functionality.
		force_close = true, -- passed into vim.api.nvim_win_close's second argument. See :h nvim_win_close
		bufhidden = "wipe", -- the bufhidden option to set on the floating window. See :h bufhidden
		stack_floating_preview_windows = true, -- Whether to nest floating windows
		same_file_float_preview = true, -- Whether to open a new floating window for a reference within the current file
		preview_window_title = { enable = true, position = "left" }, -- Whether to set the preview window title as the filename
		zindex = 1, -- Starting zindex for the stack of floating windows
		vim_ui_input = true, -- Whether to override vim.ui.input with a goto-preview floating window
	},
	keys = {
		{
			"<leader>pd",
			"<cmd>lua require('goto-preview').goto_preview_definition()<CR>",
			noremap = true,
			desc = "goto preview definition",
		},
		{
			"<leader>pD",
			"<cmd>lua require('goto-preview').goto_preview_declaration()<CR>",
			noremap = true,
			desc = "goto preview declaration",
		},
		{
			"<leader>pi",
			"<cmd>lua require('goto-preview').goto_preview_implementation()<CR>",
			noremap = true,
			desc = "goto preview implementation",
		},
		{
			"<leader>py",
			"<cmd>lua require('goto-preview').goto_preview_type_definition()<CR>",
			noremap = true,
			desc = "goto preview type definition",
		},
		{
			"<leader>pr",
			"<cmd>lua require('goto-preview').goto_preview_references()<CR>",
			noremap = true,
			desc = "goto preview references",
		},
		{
			"<leader>P",
			"<cmd>lua require('goto-preview').close_all_win()<CR>",
			noremap = true,
			desc = "close all preview windows",
		},
	},
}
