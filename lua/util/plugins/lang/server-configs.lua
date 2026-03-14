---@class LspServerConfig
---@field strategy? string force|keep
---@field cmd? string[] Command and arguments to start the language server
---@field filetypes? string[] File types this server should handle
---@field root_markers? string[] Files/directories that indicate project root
---@field settings? table Server-specific settings
---@field init_options? table Initialization options passed to server
---@field capabilities? table Server capability overrides

-- Server configurations with comprehensive settings
---@type table<string, LspServerConfig>
local configs = {
	lua_ls = {
		cmd = { "lua-language-server" },
		filetypes = { "lua" },
		root_markers = { ".luarc.json", ".luarc.jsonc", ".luacheckrc", ".stylua.toml", "stylua.toml", ".git" },
		settings = {
			Lua = {
				runtime = { version = "LuaJIT" },

				workspace = {
					checkThirdParty = false,
					-- Remove library - let lazydev manage it
					-- Reduce these if still slow:
					maxPreload = 2000,
					preloadFileSize = 1000,
				},
				diagnostics = {
					globals = { "vim", "Snacks", "icons" },
					disable = { "missing-fields", "undefined-field", "different-requires" },
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
	bashls = {
		cmd = { "bash-language-server", "start" },
		root_markers = { ".git" },
		settings = {
			bashIde = {
				globPattern = "*@(.sh|.inc|.bash|.command|PKGBUILD)",
			},
		},
		filetypes = { "sh", "bash", "PKGBUILD" },
	},

	clangd = {
		cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu" },
		filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
		root_markers = { ".clangd", "compile_commands.json", "compile_flags.txt", ".git" },
	},

	jsonls = {
		cmd = { "vscode-json-language-server", "--stdio" },
		filetypes = { "json", "jsonc" },
		root_markers = { ".git" },
		settings = {
			json = {
				validate = { enable = true },
			},
		},
	},

	yamlls = {
		cmd = { "yaml-language-server", "--stdio" },
		filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab" },
		root_markers = { ".git" },
		settings = {
			yaml = {
				keyOrdering = false,
				schemaStore = { enable = true, url = "https://www.schemastore.org/api/json/catalog.json" },
				validate = true,
			},
		},
	},

	ansiblels = {
		cmd = { "ansible-language-server", "--stdio" },
		filetypes = { "yaml.ansible" },
		root_markers = { "ansible.cfg", ".ansible-lint", "playbooks/", "roles/" },
	},

	tailwindcss = {
		cmd = { "tailwindcss-language-server", "--stdio" },
		filetypes = { "html", "css", "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte" },
		root_markers = { "tailwind.config.js", "tailwind.config.ts", "tailwind.config.cjs", "tailwind.config.mjs" },
	},

	vuels = {
		cmd = { "vue-language-server", "--stdio" },
		filetypes = { "vue" },
		root_markers = { "package.json", "vue.config.js" },
	},
	qmlls = {},
	codebook = {},
}

local M = {}
for server, config in pairs(configs) do
	-- merge with vim.lsp.config by default
	M[server] = setmetatable(config, { __index = { strategy = "force" } })
end
return M
