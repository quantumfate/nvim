--- Per-server LSP settings, merged over defaults and enabled by lspconfig.lua.

---@class LspServerConfig
---@field strategy? string force|keep
---@field cmd? string[] Command and arguments to start the language server
---@field filetypes? string[] File types this server should handle
---@field root_markers? string[] Files/directories that indicate project root
---@field settings? table Server-specific settings
---@field init_options? table Initialization options passed to server
---@field capabilities? table Server capability overrides

--- Where the distro package puts @vue/typescript-plugin. Volar 3 needs tsserver to
--- load it before ts_ls can answer anything inside a .vue file.
---@return string|nil
local function find_vue_typescript_plugin()
	local candidates = {
		"/usr/lib/node_modules/@vue/language-server/node_modules/@vue/typescript-plugin",
		"/usr/lib/node_modules/@vue/typescript-plugin",
		"/usr/lib/vue-language-server/node_modules/@vue/typescript-plugin",
	}
	for _, path in ipairs(candidates) do
		if vim.uv.fs_stat(path) then
			return path
		end
	end
	return nil
end

local vue_typescript_plugin = find_vue_typescript_plugin()

---@type table<string, LspServerConfig>
local M = {
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
		filetypes = vue_typescript_plugin
				and { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" }
			or { "javascript", "javascriptreact", "typescript", "typescriptreact" },
		root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
		init_options = {
			preferences = {
				disableSuggestions = false,
				includeCompletionsForModuleExports = true,
				includeCompletionsWithSnippetText = true,
			},
			-- Volar 3 hybrid mode: tsserver itself resolves .vue modules through this
			-- plugin, so `vue` joins ts_ls's filetypes below. Absent when the package
			-- is not installed, in which case ts_ls stays a plain TS server.
			plugins = vue_typescript_plugin and {
				{
					name = "@vue/typescript-plugin",
					location = vue_typescript_plugin,
					languages = { "vue" },
				},
			} or nil,
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

	bacon_ls = {
		enabled = true,
	},
	-- it's managed by rustaceanvim
	rust_analyzer = { enabled = false },
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
		-- PKGBUILD resolves to filetype `bash`; globPattern is what actually picks it up.
		filetypes = { "sh", "bash" },
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
		root_markers = {
			"ansible.cfg",
			".ansible-lint",
			"playbook.yml",
			"playbook.yaml",
			"playbooks/",
			"roles/",
			"galaxy.yml",
		},
		settings = {
			-- ansiblels reads this key and prompts for a telemetry choice when it is unset.
			["redhat.telemetry.enabled"] = false,
			ansible = {
				ansible = {
					path = "ansible",
					-- Completes and inserts modules as collection.namespace.module, which is what
					-- ansible-lint's fqcn rules demand.
					useFullyQualifiedCollectionNames = true,
				},
				executionEnvironment = { enabled = false },
				python = { interpreterPath = "python" },
				completion = {
					provideRedirectModules = true,
					provideModuleOptionAliases = true,
				},
				validation = {
					enabled = true,
					-- nvim-lint already runs ansible-lint on save; keep diagnostics single-sourced.
					lint = { enabled = false },
				},
			},
		},
	},

	tailwindcss = {
		cmd = { "tailwindcss-language-server", "--stdio" },
		filetypes = { "html", "css", "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte" },
		root_markers = {
			"tailwind.config.js",
			"tailwind.config.ts",
			"tailwind.config.cjs",
			"tailwind.config.mjs",
			"postcss.config.js",
			"postcss.config.cjs",
			"postcss.config.mjs",
			-- Tailwind v4 configures itself from `@import "tailwindcss"` in a stylesheet,
			-- so a project can legitimately have no config file at all.
			"package.json",
		},
	},

	svelte = {
		cmd = { "svelteserver", "--stdio" },
		filetypes = { "svelte" },
		root_markers = { "package.json", "svelte.config.js", "svelte.config.ts", ".git" },
		settings = {
			svelte = {
				plugin = {
					html = { completions = { enable = true, emmet = false } },
					svelte = { completions = { enable = true }, format = { enable = false } },
					css = { completions = { enable = true, emmet = true } },
				},
			},
		},
	},

	taplo = {
		cmd = { "taplo", "lsp", "stdio" },
		filetypes = { "toml" },
		root_markers = { ".taplo.toml", "taplo.toml", "Cargo.toml", ".git" },
	},

	marksman = {
		cmd = { "marksman", "server" },
		filetypes = { "markdown", "markdown.mdx" },
		root_markers = { ".marksman.toml", ".git" },
	},

	-- Volar 3. TypeScript inside an SFC is answered by ts_ls through the
	-- @vue/typescript-plugin wired into its init_options above; vue_ls owns the
	-- template, style and script-setup halves.
	vue_ls = {
		cmd = { "vue-language-server", "--stdio" },
		filetypes = { "vue" },
		root_markers = { "package.json", "vue.config.js", "vite.config.ts", ".git" },
	},
	zls = {
		cmd = { "zls" },
		-- `.zon` files resolve to filetype `zig` (runtime filetype.lua); zls reads both.
		filetypes = { "zig" },
		root_markers = { "zls.json", "build.zig", "build.zig.zon", ".git" },
		settings = {
			-- ZLS 0.16 settings (see `zls --show-config-path` / zigtools schema).
			zls = {
				enable_snippets = true,
				enable_argument_placeholders = true,
				completion_label_details = true,
				-- enable_build_on_save is deliberately unset: ZLS's default enables it
				-- only when build.zig declares the `check` step named below. Forcing it
				-- on makes every project without that step fail the build on each save.
				build_on_save_args = { "check" },
				semantic_tokens = "full",
				warn_style = false,
				inlay_hints_show_variable_type_hints = true,
				inlay_hints_show_parameter_name = true,
				inlay_hints_exclude_single_argument = true,
				prefer_ast_check_as_child_process = true,
			},
		},
	},
	qmlls = {
		-- Use the system qmlls6 (real Qt 6.11, matches the Qt Quickshell is built
		-- against) instead of Mason's limited standalone build, and point it at the
		-- QML import root so `import Quickshell`/`import QtQuick` resolve for
		-- completion. Quickshell installs its modules under /usr/lib/qt6/qml.
		cmd = { "qmlls6", "-I", "/usr/lib/qt6/qml" },
		filetypes = { "qml", "qmljs" },
		root_markers = { ".qmlls.ini", "shell.qml", ".git" },
		handlers = {
			["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
				-- filter out known-bad Quickshell import diagnostics
				if result and result.diagnostics then
					result.diagnostics = vim.tbl_filter(function(d)
						return not d.message:find("Type PanelWindow is not creatable.")
					end, result.diagnostics)
				end
				vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx, config)
			end,
		},
	},
	-- Lint diagnostics, import sorting and quick fixes; basedpyright is types only.
	ruff = {
		cmd = { "ruff", "server" },
		filetypes = { "python" },
		root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
		init_options = {
			settings = {
				-- conform runs `ruff format` on save; the server only lints and fixes.
				lineLength = 88,
				fixAll = true,
				organizeImports = true,
			},
		},
	},

	html = {
		cmd = { "vscode-html-language-server", "--stdio" },
		filetypes = { "html", "templ" },
		root_markers = { "package.json", ".git" },
		-- The server does nothing until told which snippets to offer.
		init_options = {
			provideFormatter = false, -- prettier via conform
			embeddedLanguages = { css = true, javascript = true },
			configurationSection = { "html", "css", "javascript" },
		},
	},

	cssls = {
		cmd = { "vscode-css-language-server", "--stdio" },
		filetypes = { "css", "scss", "less" },
		root_markers = { "package.json", ".git" },
		init_options = { provideFormatter = false },
		settings = {
			-- Tailwind's at-rules are unknown to the plain CSS grammar.
			css = { validate = true, lint = { unknownAtRules = "ignore" } },
			scss = { validate = true, lint = { unknownAtRules = "ignore" } },
			less = { validate = true },
		},
	},

	dockerls = {
		cmd = { "docker-langserver", "--stdio" },
		filetypes = { "dockerfile" },
		root_markers = { "Dockerfile", "Containerfile", ".git" },
		-- hadolint via nvim-lint owns the rule diagnostics; this is completion only.
		settings = { docker = { languageserver = { formatter = { ignoreMultilineInstructions = true } } } },
	},

	--codebook = {},
}

return M
