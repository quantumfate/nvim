--- refactoring.nvim spec: language-aware extract/inline refactors with buffer-local keymaps.

---@class plugins.coding.refactoring.Config
---@field prompt_func_return_type table<string, boolean> Languages requiring return type prompts
---@field prompt_func_param_type table<string, boolean> Languages requiring parameter type prompts
---@field printf_statements table Custom printf statement configurations
---@field print_var_statements table Custom print variable statement configurations
---@field show_success_message boolean Whether to show success notifications

--- Filetypes offered any refactor.
---@type string[]
local supported_ft = { "lua", "python", "go", "rust", "javascript", "typescript", "c", "cpp", "java" }
--- Subset that also supports block-level extraction.
---@type string[]
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
	--- Register refactoring keymaps per buffer once its filetype is known.
	config = function(_, opts)
		require("refactoring").setup(opts)

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("refactoring_keymaps", { clear = true }),
			pattern = supported_ft,
			callback = function(event)
				local buf = event.buf

				-- Refactors need a treesitter parse; skip buffers without one.
				if not pcall(vim.treesitter.get_parser, buf) then
					return
				end

				local wk = require("which-key")

				-- Extract/inline/debug refactors available in every supported filetype.
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

				-- Block-extraction refactors, added only for languages that support them.
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
