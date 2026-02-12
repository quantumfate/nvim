--- Linting plugin with capability-aware configuration
--- Provides external linter integration with conditional keymap registration
---@class plugins.coding.nvim_lint
---@field linters_by_ft table<string, string[]> Linters mapped by filetype
---@field setup fun(): nil
return {
	"mfussenegger/nvim-lint",
	event = { "User FileOpened" },
	keys = {
		{
			"<leader>cl",
			function()
				local lint = require("lint")
				local ft = vim.bo.filetype
				local linters = lint.linters_by_ft[ft] or {}

				if #linters == 0 then
					Snacks.notify.warn("No linters configured for " .. ft)
					return
				end

				lint.try_lint()
				Snacks.notify.info("Linting with: " .. table.concat(linters, ", "))
			end,
			desc = "Lint buffer",
		},
	},
	config = function()
		local lint = require("lint")

		lint.linters_by_ft = {
			python = {},
			javascript = { "eslint_d" },
			typescript = { "eslint_d" },
			javascriptreact = { "eslint_d" },
			typescriptreact = { "eslint_d" },
			sh = { "shellcheck" },
			fish = { "fish" },
			markdown = { "markdownlint" },
			yaml = { "yamllint" },
			dockerfile = { "hadolint" },
			nix = { "nix" },
			rust = { "rust_analyzer" },
		}

		-- Auto-lint on events (only if linters exist)
		vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
			group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
			callback = function()
				local ft = vim.bo.filetype
				local linters = lint.linters_by_ft[ft] or {}
				if #linters > 0 then
					lint.try_lint()
				end
			end,
		})
	end,
}
