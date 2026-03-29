return {

	{
		"lewis6991/gitsigns.nvim",
		event = "User FileOpened",
		opts = {
			signs = {
				add = { text = "▎" },
				change = { text = "▎" },
				delete = { text = "" },
				topdelete = { text = "" },
				changedelete = { text = "▎" },
				untracked = { text = "▎" },
			},
			signs_staged = {
				add = { text = "▎" },
				change = { text = "▎" },
				delete = { text = "" },
				topdelete = { text = "" },
				changedelete = { text = "▎" },
			},
			signcolumn = false,
			attach_to_untracked = true,
			current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
			current_line_blame_opts = {
				virt_text = true,
				virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
				delay = 1000,
				ignore_whitespace = false,
			},
			on_attach = function(bufnr)
				local gitsigns = require("gitsigns")
				local wk = require("which-key")
				wk.add({
					-- Navigation
					{
						"]c",
						function()
							if vim.wo.diff then
								vim.cmd.normal({ "]c", bang = true })
							else
								gitsigns.nav_hunk("next")
							end
						end,
						desc = "Next Hunk",
						buffer = bufnr,
					},
					{
						"[c",
						function()
							if vim.wo.diff then
								vim.cmd.normal({ "[c", bang = true })
							else
								gitsigns.nav_hunk("prev")
							end
						end,
						desc = "Prev Hunk",
						buffer = bufnr,
					},

					-- Actions
					{ "<leader>gs", gitsigns.stage_hunk, desc = "Stage Hunk", buffer = bufnr },
					{ "<leader>gr", gitsigns.reset_hunk, desc = "Reset Hunk", buffer = bufnr },
					{
						"<leader>gs",
						function()
							gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
						end,
						desc = "Stage Hunk",
						mode = "v",
						buffer = bufnr,
					},
					{
						"<leader>gr",
						function()
							gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
						end,
						desc = "Reset Hunk",
						mode = "v",
						buffer = bufnr,
					},
					{ "<leader>gS", gitsigns.stage_buffer, desc = "Stage Buffer", buffer = bufnr },
					{ "<leader>gR", gitsigns.reset_buffer, desc = "Reset Buffer", buffer = bufnr },
					{ "<leader>gp", gitsigns.preview_hunk, desc = "Preview Hunk", buffer = bufnr },
					{ "<leader>gi", gitsigns.preview_hunk_inline, desc = "Preview Hunk Inline", buffer = bufnr },
					{
						"<leader>gb",
						function()
							gitsigns.blame_line({ full = true })
						end,
						desc = "Blame Line",
						buffer = bufnr,
					},
					{ "<leader>gd", gitsigns.diffthis, desc = "Diff This", buffer = bufnr },
					{
						"<leader>gD",
						function()
							gitsigns.diffthis("~")
						end,
						desc = "Diff This ~",
						buffer = bufnr,
					},
					{
						"<leader>gQ",
						function()
							gitsigns.setqflist("all")
						end,
						desc = "Quickfix All Hunks",
						buffer = bufnr,
					},
					{ "<leader>gq", gitsigns.setqflist, desc = "Quickfix Hunks", buffer = bufnr },

					-- Toggles
					{ "<leader>gtb", gitsigns.toggle_current_line_blame, desc = "Toggle Line Blame", buffer = bufnr },
					{ "<leader>gtw", gitsigns.toggle_word_diff, desc = "Toggle Word Diff", buffer = bufnr },

					-- Text object
					{ "ih", gitsigns.select_hunk, desc = "Select Hunk", mode = { "o", "x" }, buffer = bufnr },
				})
			end,
		},
	},
	{
		"gitsigns.nvim",
		opts = function()
			Snacks.toggle({
				name = "Git Signs",
				get = function()
					return require("gitsigns.config").config.signcolumn
				end,
				set = function(state)
					require("gitsigns").toggle_signs(state)
				end,
			}):map("<leader>tG")
		end,
	},
}
