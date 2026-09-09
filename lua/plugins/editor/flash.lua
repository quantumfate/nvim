--- flash.nvim: label-based motions for jumps, treesitter selection, and picker navigation.
return {
	"folke/flash.nvim",
	opts = {
		-- Programmer Dvorak home row. Label order is fixed and consumed front-to-back.
		labels = "aoeuidhtns",
		search = {
			-- Stop skipping label chars that could continue the pattern after 1 char,
			-- so the Nth match always gets the Nth label. Costs pattern refining:
			-- the search ends in a jump once the pattern exceeds this length.
			max_length = 1,
		},
		label = {
			distance = false, -- order matches top-to-bottom, not nearest-to-cursor
			reuse = "none", -- no labels carried over from the previous keystroke
		},
		jump = {
			autojump = true,
		},
		modes = {
			search = {
				enabled = false, -- flash off during / and ? search
			},
			-- Char mode is off: it takes over f/F/t/T with its own jump implementation,
			-- which the treesitter repeat wrapper cannot see. `;` / `,` would then go
			-- dead after every f/t move. f/F/t/T are mapped as repeatable motions in
			-- plugins/editor/treesitter.lua instead; `s` covers what char mode offered.
			char = {
				enabled = false,
			},
		},
	},
	specs = {
		{
			"folke/snacks.nvim",
			opts = {

				picker = {
					win = {
						input = {
							keys = {
								["<a-s>"] = { "flash", mode = { "n", "i" } },
								["s"] = { "flash" },
							},
						},
					},
					actions = {
						-- Label rows in the Snacks picker list and jump to the chosen one.
						---@param picker snacks.Picker
						flash = function(picker)
							require("flash").jump({
								pattern = "^",
								label = { after = { 0, 0 }, distance = false, reuse = "none" },
								search = {
									mode = "search",
									-- Same deterministic labels as the global config; this
									-- table replaces the top-level `search` opts wholesale.
									max_length = 1,
									exclude = {
										function(win)
											return vim.bo[vim.api.nvim_win_get_buf(win)].filetype
												~= "snacks_picker_list"
										end,
									},
								},
								action = function(match)
									local idx = picker.list:row2idx(match.pos[1])
									picker.list:_move(idx, true, true)
								end,
							})
						end,
					},
				},
			},
		},
	},
  -- stylua: ignore
  keys = {
      { "s",     mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
      { "S",     mode = { "n", "o", "x" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
      { "r",     mode = "o",               function() require("flash").remote() end,            desc = "Remote Flash" },
      { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search" },


  },
}
