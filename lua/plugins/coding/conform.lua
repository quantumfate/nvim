--- Code formatting plugin with capability-aware configuration
--- Provides external formatter integration with conditional keymap registration
---@class plugins.coding.conform
---@field formatters_by_ft table<string, string[]> Formatters mapped by filetype
---@field format_on_save? fun(bufnr: integer): table|nil Configuration for automatic formatting

---@class ConformFormatOptions
---@field async? boolean Whether to format asynchronously
---@field lsp_fallback? boolean Whether to fall back to LSP formatting
---@field timeout_ms? integer Timeout for formatting operation
---@field formatters? string[] Specific formatters to use

return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>cf",
			function()
				local buf = vim.api.nvim_get_current_buf()
				local ft = vim.bo[buf].filetype
				local conform = require("conform")

				local formatters = conform.list_formatters_for_buffer(buf)
				if #formatters == 0 then
					local clients = vim.lsp.get_clients({ bufnr = buf })
					local has_lsp_formatting = false
					for _, client in ipairs(clients) do
						if client:supports_method("textDocument/formatting") then
							has_lsp_formatting = true
							break
						end
					end

					if has_lsp_formatting then
						vim.lsp.buf.format({ async = true })
						Snacks.notify.info("Formatted with LSP (no external formatter)")
					else
						Snacks.notify.warn("No formatter available for " .. ft)
					end
					return
				end

				conform.format({ async = true, lsp_fallback = true })
			end,
			mode = { "n", "v" },
			desc = "Format buffer",
		},
		{
			"<leader>cF",
			function()
				require("conform").format({ formatters = { "injected" }, timeout_ms = 3000 })
			end,
			mode = { "n", "v" },
			desc = "Format injected langs",
		},
	},
	opts = {
		formatters_by_ft = {
			lua = { "stylua" },
			python = { "ruff_format", "black" },
			javascript = { "prettierd", "prettier" },
			typescript = { "prettierd", "prettier" },
			javascriptreact = { "prettierd", "prettier" },
			typescriptreact = { "prettierd", "prettier" },
			vue = { "prettierd", "prettier" },
			svelte = { "prettierd", "prettier" },
			json = { "prettierd", "prettier" },
			jsonc = { "prettierd", "prettier" },
			yaml = { "prettierd", "prettier" },
			["yaml.ansible"] = { "prettierd", "prettier" },
			markdown = { "prettierd", "prettier" },
			html = { "prettierd", "prettier" },
			css = { "prettierd", "prettier" },
			scss = { "prettierd", "prettier" },
			sh = { "shfmt" },
			bash = { "shfmt" },
			fish = { "fish_indent" },
			go = { "goimports", "gofmt" },
			rust = { "rustfmt" },
			toml = { "taplo" },
			c = { "clang-format" },
			cpp = { "clang-format" },
			objc = { "clang-format" },
			cuda = { "clang-format" },
			["_"] = { "trim_whitespace" },
			["*"] = { "codespell" },
		},
		format_on_save = function(bufnr)
			-- Disable for certain filetypes
			local ignore_filetypes = { "sql" }
			if vim.tbl_contains(ignore_filetypes, vim.bo[bufnr].filetype) then
				return
			end
			-- Disable with a global or buffer-local toggle
			if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
				return
			end
			return {
				timeout_ms = 3000,
				lsp_fallback = true,
			}
		end,
		formatters = {
			injected = { options = { ignore_errors = true } },
			shfmt = {
				prepend_args = { "-i", "4" }, -- 4 space indent
			},
			prettierd = {
				env = {
					PRETTIERD_LOCAL_PRETTIER_ONLY = "1",
				},
			},
		},
	},
	init = function()
		-- Toggle commands
		vim.api.nvim_create_user_command("FormatDisable", function(args)
			if args.bang then
				vim.b.disable_autoformat = true
			else
				vim.g.disable_autoformat = true
			end
			Snacks.notify.info("Format on save disabled")
		end, { bang = true, desc = "Disable format on save (bang for buffer only)" })

		vim.api.nvim_create_user_command("FormatEnable", function()
			vim.b.disable_autoformat = false
			vim.g.disable_autoformat = false
			Snacks.notify.info("Format on save enabled")
		end, { desc = "Enable format on save" })

		vim.api.nvim_create_user_command("FormatToggle", function(args)
			if args.bang then
				vim.b.disable_autoformat = not vim.b.disable_autoformat
			else
				vim.g.disable_autoformat = not vim.g.disable_autoformat
			end
			local status = vim.g.disable_autoformat and "disabled" or "enabled"
			Snacks.notify.info("Format on save " .. status)
		end, { bang = true, desc = "Toggle format on save" })
	end,
}
