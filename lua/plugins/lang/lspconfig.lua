--- LSP configuration with comprehensive capability-aware features and server management
--- Provides intelligent LSP integration with conditional keymaps based on server capabilities
---@class plugins.lang.lspconfig
---@field setup fun(): nil

return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"mason.nvim",
		"mason-lspconfig.nvim",
		"folke/lazydev.nvim", -- Make sure this loads first
	},
	config = function()
		-- Capability-aware keymap registration on LSP attach
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("lsp_attach", { clear = true }),

			callback = function(event)
				local client = vim.lsp.get_client_by_id(event.data.client_id)
				if not client then
					return
				end

				-- Register capability-aware keymaps
				for _, keymap in ipairs(require("util.plugins.lang.keymaps")) do
					-- Check LSP capability
					local has_capability = keymap.method == nil or client:supports_method(keymap.method)

					-- Check additional condition
					local passes_cond = keymap.cond == nil or keymap.cond()

					if has_capability and passes_cond then
						local modes = keymap.mode or "n"
						local rhs = keymap.func or keymap.cmd --[[@as function|string]]

						vim.keymap.set(modes, keymap.keys, rhs, {
							buffer = event.buf,
							desc = "LSP: " .. keymap.desc,
							expr = keymap.expr or false,
						})
					end
				end
				-- Server-specific features
				if client.name == "clangd" then
					vim.keymap.set("n", "<leader>ch", "<cmd>ClangdSwitchSourceHeader<cr>", {
						buffer = event.buf,
						desc = "LSP: Switch Source/Header",
					})
				end

				-- Inlay hints toggle (for supporting servers)
				if client:supports_method("textDocument/inlayHint") then
					vim.keymap.set("n", "<leader>th", function()
						local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf })
						vim.lsp.inlay_hint.enable(not enabled, { bufnr = event.buf })
						Snacks.notify.info("Inlay hints " .. (enabled and "disabled" or "enabled"))
					end, {
						buffer = event.buf,
						desc = "LSP: Toggle Inlay Hints",
					})
				end

				-- Document highlight (if supported)
				if client:supports_method("textDocument/documentHighlight") then
					local group = vim.api.nvim_create_augroup("lsp_document_highlight", { clear = false })
					vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
						buffer = event.buf,
						group = group,
						callback = vim.lsp.buf.document_highlight,
					})
					vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
						buffer = event.buf,
						group = group,
						callback = vim.lsp.buf.clear_references,
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

		-- Apply server configurations
		local server_configs = require("util.plugins.lang.server-configs")
		for server, config in pairs(server_configs) do
			local strategy = config.strategy or "force"
			vim.lsp.config[server] = vim.tbl_deep_extend(strategy, vim.lsp.config[server] or {}, config)
		end
		-- Enable configured servers
		local servers = vim.tbl_keys(server_configs)
		vim.lsp.enable(servers)

		-- Add user command for debugging LSP capabilities
		vim.api.nvim_create_user_command("LspCapabilities", function()
			local buf = vim.api.nvim_get_current_buf()
			local clients = vim.lsp.get_clients({ bufnr = buf })

			if #clients == 0 then
				Snacks.notify.warn("No LSP clients attached to current buffer")
				return
			end

			local lines = { "# LSP Capabilities for current buffer\n" }
			for _, client in ipairs(clients) do
				table.insert(lines, "## " .. client.name .. "\n")
				local expected = require("util.plugins.lang.capabilities")[client.name] or {}

				for capability, expected_support in pairs(expected) do
					local method_map = {
						completion = "textDocument/completion",
						hover = "textDocument/hover",
						definition = "textDocument/definition",
						references = "textDocument/references",
						rename = "textDocument/rename",
						formatting = "textDocument/formatting",
						codeAction = "textDocument/codeAction",
						inlayHints = "textDocument/inlayHint",
					}

					local method = method_map[capability]
					local actual_support = method and client:supports_method(method) or false
					local status = actual_support and "✓" or "✗"
					local note = (expected_support == actual_support) and "" or " (unexpected)"

					table.insert(lines, string.format("- %s %s%s", status, capability, note))
				end
				table.insert(lines, "")
			end

			vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "LSP Capabilities" })
		end, { desc = "Show LSP capabilities for current buffer" })
	end,
}
