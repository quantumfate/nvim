--- todo-comments.nvim: highlight TODO/FIX/etc. keywords and navigate/search them.
return {
	"folke/todo-comments.nvim",
	event = { "User FileOpened" },
	dependencies = { "nvim-lua/plenary.nvim" },
	opts = {},
	keys = {
		{
			"]t",
			function()
				require("todo-comments").jump_next()
			end,
			desc = "Next Todo Comment",
		},
		{
			"[t",
			function()
				require("todo-comments").jump_prev()
			end,
			desc = "Previous Todo Comment",
		},
		{
			"<leader>ft",
			-- `Snacks` is a global from snacks.nvim.
			function()
				Snacks.picker.todo_comments()
			end,
			desc = "Todo",
		},
		{
			"<leader>fT",
			function()
				Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } })
			end,
			desc = "Todo/Fix/Fixme",
		},
	},
}
