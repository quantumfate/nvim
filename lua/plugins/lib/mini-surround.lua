return {
	"nvim-mini/mini.surround",
	event = "User FileOpened",
	opts = {
		-- Use 'gs' prefix instead of 's' to avoid conflicts
		mappings = {
			add = "gsa", -- Add surrounding
			delete = "gsd", -- Delete surrounding
			find = "gsf", -- Find surrounding (to the right)
			find_left = "gsF", -- Find surrounding (to the left)
			highlight = "gsh", -- Highlight surrounding
			replace = "gsr", -- Replace surrounding
			update_n_lines = "gsn", -- Update `n_lines`
		},
	},
	keys = {
		{ "gsa", desc = "Add surrounding" },
		{ "gsd", desc = "Delete surrounding" },
		{ "gsf", desc = "Find surrounding (to the right)" },
		{ "gsF", desc = "Find surrounding (to the left)" },
		{ "gsh", desc = "Highlight surrounding" },
		{ "gsr", desc = "Replace surrounding" },
		{ "gsn", desc = "Update N lines" },
	},
}
