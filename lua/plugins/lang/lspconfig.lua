--- LSP configuration with comprehensive capability-aware features and server management
--- Provides intelligent LSP integration with conditional keymaps based on server capabilities
---@class plugins.lang.lspconfig
---@field setup fun(): nil

---@class LspServerConfig
---@field cmd string[] Command and arguments to start the language server
---@field filetypes string[] File types this server should handle
---@field root_markers string[] Files/directories that indicate project root
---@field settings? table Server-specific settings
---@field init_options? table Initialization options passed to server
---@field capabilities? table Server capability overrides

---@class LspKeymapConfig
---@field keys string Keymap sequence
---@field func? function|string Function to execute or command string
---@field cmd? string Command string (alternative to func)
---@field desc string Keymap description
---@field method? string LSP method for capability check
---@field mode? string|string[] Vim modes (default: "n")
---@field expr? boolean Whether the function returns a string to execute
---@field cond? fun(): boolean Additional condition check

return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"mason.nvim",
		"mason-lspconfig.nvim",
		"folke/lazydev.nvim", -- Make sure this loads first
	},
	config = function()
		-- Disable stylua LSP completely (we use conform.nvim for formatting)
		vim.lsp.config("stylua", {
			cmd = {}, -- Empty cmd prevents it from starting
		})

		--- LSP capability matrix for reference and debugging
		---@type table<string, table<string, boolean>>
		local capability_matrix = {
			lua_ls = {
				completion = true,
				hover = true,
				definition = true,
				references = true,
				rename = true,
				formatting = false, -- Use stylua via conform
				codeAction = true,
				inlayHints = true,
				switchSourceHeader = false,
			},
			basedpyright = {
				completion = true,
				hover = true,
				definition = true,
				references = true,
				rename = true,
				formatting = false, -- Use black/ruff via conform
				codeAction = true,
				inlayHints = true,
				switchSourceHeader = false,
			},
			gopls = {
				completion = true,
				hover = true,
				definition = true,
				references = true,
				rename = true,
				formatting = true,
				codeAction = true,
				inlayHints = true,
				switchSourceHeader = false,
			},
			rust_analyzer = {
				completion = true,
				hover = true,
				definition = true,
				references = true,
				rename = true,
				formatting = true,
				codeAction = true,
				inlayHints = true,
				switchSourceHeader = false,
			},
			ts_ls = {
				completion = true,
				hover = true,
				definition = true,
				references = true,
				rename = true,
				formatting = false, -- Use prettier via conform
				codeAction = true,
				inlayHints = true,
				switchSourceHeader = false,
			},
			clangd = {
				completion = true,
				hover = true,
				definition = true,
				references = true,
				rename = true,
				formatting = true,
				codeAction = true,
				inlayHints = true,
				switchSourceHeader = true,
			},
		}

		--- Standard LSP keymaps with capability checks
		---@type LspKeymapConfig[]
		local lsp_keymaps = {
			-- Core navigation
			{
				keys = "gd",
				func = vim.lsp.buf.definition,
				desc = "Goto Definition",
				method = "textDocument/definition",
			},
			{
				keys = "gD",
				func = vim.lsp.buf.declaration,
				desc = "Goto Declaration",
				method = "textDocument/declaration",
			},
			{ keys = "gr", func = vim.lsp.buf.references, desc = "References", method = "textDocument/references" },
			{
				keys = "gI",
				func = vim.lsp.buf.implementation,
				desc = "Goto Implementation",
				method = "textDocument/implementation",
			},
			{
				keys = "gy",
				func = vim.lsp.buf.type_definition,
				desc = "Type Definition",
				method = "textDocument/typeDefinition",
			},

			-- Documentation
			{ keys = "K", func = vim.lsp.buf.hover, desc = "Hover Documentation", method = "textDocument/hover" },
			{
				keys = "gK",
				func = vim.lsp.buf.signature_help,
				desc = "Signature Help",
				method = "textDocument/signatureHelp",
			},

			-- Code actions and refactoring
			{
				keys = "<leader>ca",
				func = vim.lsp.buf.code_action,
				desc = "Code Action",
				method = "textDocument/codeAction",
				mode = { "n", "v" },
			},
			{
				keys = "<leader>cr",
				func = vim.lsp.buf.rename,
				desc = "Rename",
				method = "textDocument/rename",
			},
			{
				keys = "<leader>cR",
				func = function()
					return ":IncRename " .. vim.fn.expand("<cword>")
				end,
				desc = "Inc-Rename",
				expr = true,
				method = "textDocument/rename",
			},
			-- Formatting (only for servers that support it)
			{
				keys = "<leader>cf",
				func = vim.lsp.buf.format,
				desc = "Format Document",
				method = "textDocument/formatting",
			},

			-- Diagnostics (always available - not server-specific)
			{ keys = "<leader>cd", func = vim.diagnostic.open_float, desc = "Line Diagnostics" },
			{
				keys = "]d",
				func = function()
					vim.diagnostic.jump({ count = 1 })
				end,
				desc = "Next Diagnostic",
			},
			{
				keys = "[d",
				func = function()
					vim.diagnostic.jump({ count = -1 })
				end,
				desc = "Prev Diagnostic",
			},
		}

		-- Capability-aware keymap registration on LSP attach
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("lsp_attach", { clear = true }),
			callback = function(event)
				local client = vim.lsp.get_client_by_id(event.data.client_id)
				if not client then
					return
				end

				-- Register capability-aware keymaps
				for _, keymap in ipairs(lsp_keymaps) do
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

		-- Server configurations with comprehensive settings
		---@type table<string, LspServerConfig>
		local server_configs = {
			lua_ls = {
				cmd = { "lua-language-server" },
				filetypes = { "lua" },
				root_markers = { ".luarc.json", ".luarc.jsonc", ".luacheckrc", ".stylua.toml", "stylua.toml", ".git" },
				settings = {
					Lua = {
						runtime = {
							version = "LuaJIT",
							path = vim.split(package.path, ";"),
						},
						diagnostics = {
							globals = { "vim", "Snacks", "icons" },
							disable = { "missing-fields" },
						},
						workspace = {
							checkThirdParty = false,
							library = vim.api.nvim_get_runtime_file("", true),
							maxPreload = 100000,
							preloadFileSize = 10000,
						},
						telemetry = { enable = false },
						codeLens = { enable = true },
						completion = {
							callSnippet = "Replace",
							keywordSnippet = "Replace",
							displayContext = 5,
						},
						doc = { privateName = { "^_" } },
						hint = {
							enable = true,
							setType = false,
							paramType = true,
							paramName = "Disable",
							semicolon = "Disable",
							arrayIndex = "Disable",
						},
						format = {
							enable = false, -- Use stylua via conform
						},
					},
				},
			},

			basedpyright = {
				cmd = { "basedpyright-langserver", "--stdio" },
				filetypes = { "python" },
				root_markers = {
					"pyproject.toml",
					"setup.py",
					"setup.cfg",
					"requirements.txt",
					"Pipfile",
					"pyrightconfig.json",
					".git",
				},
				settings = {
					basedpyright = {
						disableOrganizeImports = true, -- Use ruff via conform
						analysis = {
							typeCheckingMode = "standard",
							diagnosticSeverityOverrides = {
								reportUnusedImport = "none", -- ruff handles this
								reportUnusedVariable = "none", -- ruff handles this
								reportUnusedClass = "none",
								reportUnusedFunction = "none",
								reportGeneralTypeIssues = "error",
								reportOptionalMemberAccess = "warning",
							},
							stubPath = vim.fn.stdpath("data") .. "/lazy/python-type-stubs",
						},
					},
				},
			},

			ts_ls = {
				cmd = { "typescript-language-server", "--stdio" },
				filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
				root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
				init_options = {
					preferences = {
						disableSuggestions = false,
						includeCompletionsForModuleExports = true,
						includeCompletionsWithSnippetText = true,
					},
				},
				settings = {
					typescript = {
						inlayHints = {
							includeInlayParameterNameHints = "literal",
							includeInlayParameterNameHintsWhenArgumentMatchesName = false,
							includeInlayFunctionParameterTypeHints = true,
							includeInlayVariableTypeHints = false,
							includeInlayPropertyDeclarationTypeHints = true,
							includeInlayFunctionLikeReturnTypeHints = true,
							includeInlayEnumMemberValueHints = true,
						},
					},
					javascript = {
						inlayHints = {
							includeInlayParameterNameHints = "all",
							includeInlayParameterNameHintsWhenArgumentMatchesName = false,
							includeInlayFunctionParameterTypeHints = true,
							includeInlayVariableTypeHints = true,
							includeInlayPropertyDeclarationTypeHints = true,
							includeInlayFunctionLikeReturnTypeHints = true,
							includeInlayEnumMemberValueHints = true,
						},
					},
				},
			},

			rust_analyzer = {
				cmd = { "rust-analyzer" },
				filetypes = { "rust" },
				root_markers = { "Cargo.toml", "rust-project.json" },
				settings = {
					["rust-analyzer"] = {
						cargo = {
							allFeatures = true,
							loadOutDirsFromCheck = true,
						},
						checkOnSave = {
							command = "clippy",
							extraArgs = { "--no-deps" },
						},
						procMacro = {
							enable = true,
							ignored = {
								["async-trait"] = { "async_trait" },
								["napi-derive"] = { "napi" },
								["async-recursion"] = { "async_recursion" },
							},
						},
						inlayHints = {
							bindingModeHints = {
								enable = false,
							},
							chainingHints = {
								enable = true,
							},
							closingBraceHints = {
								enable = true,
								minLines = 25,
							},
							closureReturnTypeHints = {
								enable = "never",
							},
							lifetimeElisionHints = {
								enable = "never",
								useParameterNames = false,
							},
							maxLength = 25,
							parameterHints = {
								enable = true,
							},
							reborrowHints = {
								enable = "never",
							},
							renderColons = true,
							typeHints = {
								enable = true,
								hideClosureInitialization = false,
								hideNamedConstructor = false,
							},
						},
					},
				},
			},

			gopls = {
				cmd = { "gopls" },
				filetypes = { "go", "gomod", "gowork", "gotmpl" },
				root_markers = { "go.work", "go.mod", ".git" },
				settings = {
					gopls = {
						gofumpt = true,
						codelenses = {
							gc_details = false,
							generate = true,
							regenerate_cgo = true,
							run_govulncheck = true,
							test = true,
							tidy = true,
							upgrade_dependency = true,
							vendor = true,
						},
						hints = {
							assignVariableTypes = true,
							compositeLiteralFields = true,
							compositeLiteralTypes = true,
							constantValues = true,
							functionTypeParameters = true,
							parameterNames = true,
							rangeVariableTypes = true,
						},
						analyses = {
							fieldalignment = true,
							nilness = true,
							unusedparams = true,
							unusedwrite = true,
							useany = true,
						},
						usePlaceholders = true,
						completeUnimported = true,
						staticcheck = true,
						directoryFilters = { "-.git", "-.vscode", "-.idea", "-.vscode-test", "-node_modules" },
						semanticTokens = true,
					},
				},
			},
		}

		-- Apply server configurations
		for server, config in pairs(server_configs) do
			vim.lsp.config[server] = config
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
				local expected = capability_matrix[client.name] or {}

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
