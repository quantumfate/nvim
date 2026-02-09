return {
	"ThePrimeagen/refactoring.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		prompt_func_return_type = {
			go = true,
			java = true,
			cpp = true,
			c = true,
			h = true,
			hpp = true,
			cxx = true,
		},
		prompt_func_param_type = {
			go = true,
			java = true,
			cpp = true,
			c = true,
			h = true,
			hpp = true,
			cxx = true,
		},
		printf_statements = {},
		print_var_statements = {},
		show_success_message = true,
	},
	config = function(_, opts)
		require("refactoring").setup(opts)

		-- HACK: Using which-key.add instead of lazy keys table
		-- because refactoring.nvim requires expr = true
		require("which-key").add({
			{
				"<leader>rs",
				function()
					require("refactoring").select_refactor()
				end,
				desc = "Select Refactor",
				mode = { "n", "x" },
			},
			{
				"<leader>re",
				function()
					return require("refactoring").refactor("Extract Function")
				end,
				desc = "Extract Function",
				mode = { "n", "x" },
				expr = true,
			},
			{
				"<leader>rf",
				function()
					return require("refactoring").refactor("Extract Function To File")
				end,
				desc = "Extract Function To File",
				mode = { "n", "x" },
				expr = true,
			},
			{
				"<leader>rv",
				function()
					return require("refactoring").refactor("Extract Variable")
				end,
				desc = "Extract Variable",
				mode = { "n", "x" },
				expr = true,
			},
			{
				"<leader>rI",
				function()
					return require("refactoring").refactor("Inline Function")
				end,
				desc = "Inline Function",
				mode = { "n", "x" },
				expr = true,
			},
			{
				"<leader>ri",
				function()
					return require("refactoring").refactor("Inline Variable")
				end,
				desc = "Inline Variable",
				mode = { "n", "x" },
				expr = true,
			},
			{
				"<leader>rbb",
				function()
					return require("refactoring").refactor("Extract Block")
				end,
				desc = "Extract Block",
				mode = { "n", "x" },
				expr = true,
			},
			{
				"<leader>rbf",
				function()
					return require("refactoring").refactor("Extract Block To File")
				end,
				desc = "Extract Block To File",
				mode = { "n", "x" },
				expr = true,
			},
			-- Debug (no expr needed)
			{
				"<leader>rp",
				function()
					require("refactoring").debug.printf({ below = true })
				end,
				desc = "Debug Print Below",
				mode = "n",
			},
			{
				"<leader>rd",
				function()
					require("refactoring").debug.print_var()
				end,
				desc = "Debug Print Variable",
				mode = { "n", "x" },
			},
			{
				"<leader>rc",
				function()
					require("refactoring").debug.cleanup({})
				end,
				desc = "Debug Cleanup",
				mode = "n",
			},
			-- Group
			{ "<leader>r", group = "refactor" },
			{ "<leader>rb", group = "block" },
		})
	end,
}
