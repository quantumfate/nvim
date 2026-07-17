--- persistence.nvim: save and restore editing sessions, keyed per directory and git branch.
---@class plugins.editor.persistence
---@field setup fun(): nil

---@class PersistenceConfig
---@field dir string Directory to store session files
---@field need integer Minimum number of buffers required to save session
---@field branch boolean Whether to include git branch name in session file

return {
	"folke/persistence.nvim",
	event = "BufReadPre",
	---@type PersistenceConfig
	opts = {
		dir = vim.fn.stdpath("state") .. "/sessions/",
		need = 1, -- minimum number of buffers to save
		branch = true, -- include branch name in session file
	},
	keys = {
		{ "<leader>qs", desc = "Restore Session" },
		{ "<leader>ql", desc = "Restore Last Session" },
		{ "<leader>qS", desc = "Select Session" },
		{ "<leader>qd", desc = "Don't Save Current Session" },
	},
	-- Set up persistence and bind the session actions through which-key.
	config = function(_, opts)
		require("persistence").setup(opts)

		require("which-key").add({
			{
				"<leader>qs",
				function()
					require("persistence").load()
				end,
				desc = "Restore Session",
			},
			{
				"<leader>ql",
				function()
					require("persistence").load({ last = true })
				end,
				desc = "Restore Last Session",
			},
			{
				"<leader>qS",
				function()
					require("persistence").select()
				end,
				desc = "Select Session",
			},
			{
				"<leader>qd",
				function()
					require("persistence").stop()
				end,
				desc = "Don't Save Current Session",
			},
		})
	end,
}
