return {
	"folke/trouble.nvim",
	cmd = { "Trouble" },
	opts = {},
	keys = {
		{
			"[q",
			function()
				if require("trouble").is_open() then
					require("trouble").prev({ skip_groups = true, jump = true })
				else
					local ok, err = pcall(vim.cmd.cprev)
					if not ok then
						Snacks.notify.error(err)
					end
				end
			end,
			desc = "Previous Trouble/Quickfix Item",
		},
		{
			"]q",
			function()
				if require("trouble").is_open() then
					require("trouble").next({ skip_groups = true, jump = true })
				else
					local ok, err = pcall(vim.cmd.cnext)
					if not ok then
						Snacks.notify.error(err)
					end
				end
			end,
			desc = "Next Trouble/Quickfix Item",
		},
	},
}
