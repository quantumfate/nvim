--- gitgraph.nvim: in-buffer branch graph, `git log --graph --all` made interactive.
--- Select hashes with <space> on the cursor (one commit) or a range (two endpoints);
--- the hooks below decide what selecting does.
return {
	{
		"isakbm/gitgraph.nvim",
		-- No event: drawing is the whole purpose, so the keymap is the loader.
		keys = {
			{
				"<leader>gG",
				function()
					require("gitgraph").draw({}, { all = true, max_count = 5000 })
				end,
				desc = "Git Graph (all branches)",
			},
		},
		opts = {
			format = {
				fields = { "hash", "timestamp", "author", "branch_name", "tag" },
			},
			hooks = {
				-- One selection previews the commit in a right-hand terminal.
				---@param commit table the picked commit (contains `hash`)
				on_select_commit = function(commit)
					vim.cmd("vertical rightbelow new | terminal git show " .. commit.hash)
				end,
				-- A range selection diffs the two endpoints.
				---@param from table the range start commit
				---@param to table the range end commit
				on_select_range_commit = function(from, to)
					vim.cmd("vertical rightbelow new | terminal git diff " .. from.hash .. " " .. to.hash)
				end,
			},
		},
	},
}
