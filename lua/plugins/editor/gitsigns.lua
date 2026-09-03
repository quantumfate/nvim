--- gitsigns.nvim: gutter signs, hunk navigation/staging, and inline blame for git buffers.
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
			signcolumn = true,
			attach_to_untracked = true,
			current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
			current_line_blame_opts = {
				virt_text = true,
				virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
				delay = 1000,
				ignore_whitespace = false,
			},
			-- Register buffer-local hunk keymaps once gitsigns attaches to a buffer.
			---@param bufnr integer
			on_attach = function(bufnr)
				local gitsigns = require("gitsigns")
				local wk = require("which-key")

				--- Wrap a direction-taking move so `;` / `,` replay it, joining the single
				--- rotation editor/treesitter.lua sets up for f/t and structural motions.
				--- The plugin flips `opts.forward` for `,`, so the move itself must read
				--- that field rather than close over a fixed direction.
				---@param move fun(forward: boolean)
				---@return fun(forward: boolean)
				local function repeatable(move)
					local ok, rm = pcall(require, "nvim-treesitter-textobjects.repeatable_move")
					if not ok then
						return move
					end
					local wrapped = rm.make_repeatable_move(function(opts)
						move(opts.forward)
					end)
					return function(forward)
						wrapped({ forward = forward })
					end
				end

				--- Jump to a hunk, honouring a count and wrapping at the ends of the file,
				--- so holding the key cycles the buffer instead of stopping at the last one.
				---@type fun(forward: boolean)
				local hunk = repeatable(function(forward)
					gitsigns.nav_hunk(forward and "next" or "prev", { count = vim.v.count1, wrap = true })
				end)

				--- The outermost hunk in each direction.
				---@type fun(forward: boolean)
				local edge_hunk = repeatable(function(forward)
					gitsigns.nav_hunk(forward and "last" or "first")
				end)

				--- In a diff split the buffer is one big hunk, so gitsigns has nothing to
				--- navigate; hand those windows back to vim's own ]c/[c.
				---@type fun(forward: boolean)
				local change = repeatable(function(forward)
					if vim.wo.diff then
						vim.cmd.normal({ forward and "]c" or "[c", bang = true })
					else
						gitsigns.nav_hunk(forward and "next" or "prev", { count = vim.v.count1, wrap = true })
					end
				end)

				--- Bind one direction of a repeatable move.
				---@param move fun(forward: boolean)
				---@param forward boolean
				---@return fun()
				local function go(move, forward)
					return function()
						move(forward)
					end
				end

				wk.add({
					-- Navigation. `-`/`_` are remapped to `]`/`[` in config/keymaps.lua,
					-- so these are reachable as -h/_h and -H/_H too. `;` repeats the last
					-- jump, `,` repeats it in the opposite direction.
					{ "]h", go(hunk, true), desc = "Next Hunk", buffer = bufnr },
					{ "[h", go(hunk, false), desc = "Prev Hunk", buffer = bufnr },
					{ "]H", go(edge_hunk, true), desc = "Last Hunk", buffer = bufnr },
					{ "[H", go(edge_hunk, false), desc = "First Hunk", buffer = bufnr },

					-- Kept for muscle memory and for diff splits, where ]c is vim's own.
					-- Being buffer-local, these shadow the global @class motion that
					-- editor/treesitter.lua binds to the same keys, but only in a buffer
					-- gitsigns attached to. ]h has no such clash.
					{ "]c", go(change, true), desc = "Next Hunk", buffer = bufnr },
					{ "[c", go(change, false), desc = "Prev Hunk", buffer = bufnr },

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
		-- Add a Snacks toggle for the sign column. `Snacks` is a global set up by snacks.nvim.
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
