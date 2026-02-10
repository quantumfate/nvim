return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>cf",
			function()
				require("conform").format({ async = true, lsp_fallback = true })
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
			json = { "prettierd", "prettier" },
			yaml = { "prettierd", "prettier" },
			markdown = { "prettierd", "prettier", "codespell" },
			html = { "prettierd", "prettier" },
			css = { "prettierd", "prettier" },
			sh = { "shfmt" },
			fish = { "fish_indent" },
			go = { "gofmt", "goimports" },
			rust = { "rustfmt" },
			nix = { "nixfmt" },
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
