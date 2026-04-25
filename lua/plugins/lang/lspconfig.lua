--- LSP configuration with comprehensive capability-aware features and server management
--- Provides intelligent LSP integration with conditional keymaps based on server capabilities
---@class plugins.lang.lspconfig
---@field setup fun(): nil

return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"folke/lazydev.nvim", -- Make sure this loads first
		"mason.nvim",
		"mason-lspconfig.nvim",
		"saghen/blink.cmp",
	},
	config = function()
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("lsp_attach", { clear = true }),
			callback = function(event)
				local client = vim.lsp.get_client_by_id(event.data.client_id)
				if not client then
					return
				end

				local buf = event.buf

				local keymaps = require("plugins.lang.conf.keymaps")

				for _, map in ipairs(keymaps) do
					-- Capability check first
					local ok = true
					if map.method and not client:supports_method(map.method) then
						ok = false
					end

					-- Optional extra condition
					if ok and map.cond and not map.cond() then
						ok = false
					end

					if ok then
						local mode = map.mode or "n"
						local rhs = map.func or map.cmd

						---@diagnostic disable-next-line: param-type-mismatch
						vim.keymap.set(mode, map.keys, rhs, {
							buffer = buf,
							desc = map.desc,
							expr = map.expr or false,
						})
					end
				end

				-- Inlay hints toggle
				if client:supports_method("textDocument/inlayHint") then
					vim.keymap.set("n", "<leader>th", function()
						local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
						vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf })
					end, { buffer = buf, desc = "Toggle Inlay Hints" })
				end

				-- Document highlight
				if client:supports_method("textDocument/documentHighlight") then
					local group = vim.api.nvim_create_augroup("lsp_document_highlight", { clear = false })

					vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
						buffer = buf,
						group = group,
						callback = vim.lsp.buf.document_highlight,
					})

					vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
						buffer = buf,
						group = group,
						callback = vim.lsp.buf.clear_references,
					})
				end

				-- Server-specific tweaks
				if client.name == "clangd" then
					vim.keymap.set("n", "<leader>ch", "<cmd>ClangdSwitchSourceHeader<cr>", {
						buffer = buf,
						desc = "Switch Source/Header",
					})
				end
			end,
		})

		-- Enhanced diagnostics configuration
		vim.diagnostic.config({
			underline = true,
			update_in_insert = false,
			virtual_text = {
				spacing = 4,
				prefix = "●",
				source = "if_many",
			},
			severity_sort = true,
			float = {
				border = "single",
				source = true,
				header = "",
				prefix = "",
				focusable = false,
			},
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = icons.diagnostics.Error,
					[vim.diagnostic.severity.WARN] = icons.diagnostics.Warning,
					[vim.diagnostic.severity.HINT] = icons.diagnostics.Hint,
					[vim.diagnostic.severity.INFO] = icons.diagnostics.Information,
				},
			},
		})

		-- In lspconfig.lua config function, before the server loop:
		vim.lsp.config("*", {
			capabilities = require("blink.cmp").get_lsp_capabilities({
				textDocument = {
					foldingRange = {
						dynamicRegistration = false,
						lineFoldingOnly = true,
					},
				},
				workspace = {
					didChangeWatchedFiles = {
						dynamicRegistration = true,
					},
				},
			}),
		})
		-- Apply server configurations
		local server_configs = require("plugins.lang.conf.server")

		for server, config in pairs(server_configs) do
			vim.lsp.config[server] = vim.tbl_deep_extend("force", vim.lsp.config[server] or {}, config)
		end
		-- Enable configured servers
		local servers = vim.tbl_keys(server_configs)
		vim.lsp.enable(servers)

		vim.api.nvim_create_user_command("LspInfo", function()
			vim.cmd("checkhealth vim.lsp")
		end, { desc = "Show LSP info" })

		vim.api.nvim_create_user_command("LspLog", function()
			vim.cmd.edit(vim.lsp.get_log_path())
		end, { desc = "Open LSP log" })

		vim.api.nvim_create_user_command("LspStart", function(opts)
			local names = #opts.fargs > 0 and opts.fargs or servers
			vim.lsp.enable(names)
		end, {
			nargs = "*",
			desc = "Enable LSP server(s)",
			complete = function()
				return servers
			end,
		})

		vim.api.nvim_create_user_command("LspStop", function(opts)
			local clients = #opts.fargs > 0 and vim.lsp.get_clients({ name = opts.fargs[1] })
				or vim.lsp.get_clients({ bufnr = 0 })
			for _, c in ipairs(clients) do
				vim.lsp.stop_client(c.id)
			end
		end, {
			nargs = "?",
			desc = "Stop LSP client(s) (default: current buffer)",
			complete = function()
				return vim.tbl_map(function(c)
					return c.name
				end, vim.lsp.get_clients())
			end,
		})

		vim.api.nvim_create_user_command("LspRestart", function(opts)
			local targets = #opts.fargs > 0 and opts.fargs
				or vim.tbl_map(function(c)
					return c.name
				end, vim.lsp.get_clients({ bufnr = 0 }))
			for _, name in ipairs(targets) do
				for _, c in ipairs(vim.lsp.get_clients({ name = name })) do
					vim.lsp.stop_client(c.id)
				end
			end
			vim.defer_fn(function()
				vim.lsp.enable(#targets > 0 and targets or servers)
				vim.cmd("edit")
			end, 100)
		end, {
			nargs = "*",
			desc = "Restart LSP client(s) (default: current buffer)",
			complete = function()
				return vim.tbl_map(function(c)
					return c.name
				end, vim.lsp.get_clients())
			end,
		})
	end,
}
