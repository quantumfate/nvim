return {
	"folke/snacks.nvim",
	opts = {
		picker = {
			win = {
				input = {
					keys = {
						["<a-c>"] = {
							"toggle_cwd",
							mode = { "n", "i" },
						},
						-- Swap Tab/S-Tab with C-j/C-k
						["<Tab>"] = { "list_down", mode = { "n", "i" } },
						["<S-Tab>"] = { "list_up", mode = { "n", "i" } },
						["<C-j>"] = { "select_and_next", mode = { "n", "i" } },
						["<C-k>"] = { "select_and_prev", mode = { "n", "i" } },
					},
				},
			},
			actions = {
				toggle_cwd = function(p)
					local root = require("util.root").get({ buf = p.input.filter.current_buf, normalize = true })
					local cwd = vim.fs.normalize((vim.uv or vim.loop).cwd() or ".")
					local current = p:cwd()
					p:set_cwd(current == root and cwd or root)
					p:find()
				end,
			},
		},
	},
}
