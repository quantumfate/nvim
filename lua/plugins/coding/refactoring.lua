---@class plugins.coding.refactoring
---@field supported_filetypes string[] List of supported programming languages

---@class plugins.coding.refactoring.Config
---@field prompt_func_return_type table<string, boolean> Languages requiring return type prompts
---@field prompt_func_param_type table<string, boolean> Languages requiring parameter type prompts
---@field printf_statements table Custom printf statement configurations
---@field print_var_statements table Custom print variable statement configurations
---@field show_success_message boolean Whether to show success notifications

local supported_ft = { "lua", "python", "go", "rust", "javascript", "typescript", "c", "cpp", "java" }
local block_ft = { "go", "rust", "c", "cpp", "java" }

return {
	"ThePrimeagen/refactoring.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	ft = supported_ft,
	---@type plugins.coding.refactoring.Config
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

		-- Register buffer-local keymaps for supported filetypes
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("refactoring_keymaps", { clear = true }),
			pattern = supported_ft,
			callback = function(event)
				local buf = event.buf

				-- Check treesitter is available
				if not pcall(vim.treesitter.get_parser, buf) then
					return
				end

				local wk = require("which-key")

				-- Base refactoring keymaps
				wk.add({
					buffer = buf,
					{ "<leader>r", group = "refactor" },
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
					-- Debug utilities
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
				})

				-- Block refactors only for supported languages
				local ft = vim.bo[buf].filetype
				if vim.tbl_contains(block_ft, ft) then
					wk.add({
						buffer = buf,
						{ "<leader>rb", group = "block" },
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
					})
				end
			end,
		})
	end,
}
