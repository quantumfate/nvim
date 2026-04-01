return {
	"mrcjkb/rustaceanvim",
	ft = { "rust" },
	dependencies = {
		"Saecki/crates.nvim",
		event = { "BufRead Cargo.toml" },
		opts = {
			completion = {
				crates = {
					enabled = true,
				},
			},
			lsp = {
				enabled = true,
				actions = true,
				completion = true,
				hover = true,
			},
		},
	},
	opts = {
		server = {
			on_attach = function(_, bufnr)
				vim.keymap.set("n", "<leader>dr", function()
					vim.cmd.RustLsp("debuggables")
				end, { desc = "Rust Debuggables", buffer = bufnr })
			end,
			default_settings = {
				-- rust-analyzer language server configuration
				["rust-analyzer"] = {
					cargo = {
						allFeatures = true,
						loadOutDirsFromCheck = true,
						buildScripts = {
							enable = true,
						},
						runBuildScripts = true,
					},
					-- Add clippy lints for Rust if using rust-analyzer
					checkOnSave = true,
					-- Enable diagnostics if using rust-analyzer
					diagnostics = {
						enable = true,
					},
					procMacro = {
						enable = true,
					},
					inlayHints = {
						bindingModeHints = { enable = true },
						closureReturnTypeHints = { enable = "always" },
						lifetimeElisionHints = { enable = "always" },
					},
					files = {
						exclude = {
							".direnv",
							".git",
							".jj",
							".github",
							".gitlab",
							"bin",
							"node_modules",
							"target",
							"venv",
							".venv",
						},
						-- Avoid Roots Scanned hanging, see https://github.com/rust-lang/rust-analyzer/issues/12613#issuecomment-2096386344
						watcher = "client",
					},
				},
			},
		},
	},
	config = function(_, opts)
		opts.dap = {
			adapter = function()
				return require("dap").adapters.codelldb
			end,
		}
		vim.g.rustaceanvim = vim.tbl_deep_extend("keep", vim.g.rustaceanvim or {}, opts or {})
		if vim.fn.executable("rust-analyzer") == 0 then
			vim.notify(
				"**rust-analyzer** not found in PATH, please install it.\nhttps://rust-analyzer.github.io/",
				vim.log.levels.ERROR,
				{ title = "rustaceanvim" }
			)
		end
	end,
}
