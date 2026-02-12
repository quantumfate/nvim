--- Capability-aware package management for LSP servers, formatters, linters, and debug adapters
--- Provides intelligent installation and configuration with ecosystem awareness
---@class plugins.lang.mason
---@field setup fun(): nil

---@class MasonPackageList
---@field lsp_servers string[] Language server packages
---@field formatters string[] Code formatter packages
---@field linters string[] Code linter packages
---@field dap_adapters string[] Debug adapter packages

---@class MasonConfig
---@field ui table UI configuration for Mason interface
---@field ensure_installed string[] Packages to automatically install
---@field automatic_installation boolean Whether to auto-install packages
---@field handlers table<string, fun(server_name: string)> Server setup handlers

--- LSP servers with capability awareness
---@type string[]
local lsp_servers = {
	"lua_ls",
	"basedpyright",
	"ts_ls",
	"rust_analyzer",
	"gopls",
	"clangd",
	"jsonls",
	"yamlls",
	"ansiblels",
	"tailwindcss",
	"bashls",
}

--- External formatters for languages where LSP doesn't provide formatting
---@type string[]
local formatters = {
	"stylua",
	"prettierd",
	"black",
	"ruff",
	"shfmt",
	"clang-format",
	"goimports",
}

--- External linters for additional code quality checks
---@type string[]
local linters = {
	"eslint_d",
	"shellcheck",
	"markdownlint",
	"yamllint",
	"hadolint",
	"ansible-lint",
	"jsonlint",
	"cpplint",
}

--- Debug adapters for supported languages
---@type string[]
local dap_adapters = {
	"debugpy", -- Python (was "python")
	"codelldb", -- Rust/C/C++
	"js-debug-adapter", -- JS/TS (was "js")
	"delve", -- Go (optional)
}

return {
	-- Mason: Package manager
	{
		"williamboman/mason.nvim",
		cmd = "Mason",
		keys = {
			{ "<leader>um", "<cmd>Mason<cr>", desc = "Mason" },
		},
		build = ":MasonUpdate",
		opts = {
			ui = {
				border = "single",
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		},
		config = function(_, opts)
			require("mason").setup(opts)

			-- Collect all packages
			local all_packages = vim.iter({ lsp_servers, formatters, linters, dap_adapters }):flatten():totable()

			-- Install available packages
			vim.defer_fn(function()
				require("mason-registry").refresh(function()
					require("util.plugins.mason").ensure_installed(all_packages)
				end)
			end, 100)
		end,
	},

	-- LSP servers
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "mason.nvim" },
		opts = {
			ensure_installed = lsp_servers,
			automatic_installation = false,
			automatic_enable = false,
		},
	},

	-- Formatters
	{
		"zapling/mason-conform.nvim",
		dependencies = { "mason.nvim", "stevearc/conform.nvim" },
		opts = {
			ensure_installed = formatters,
			automatic_installation = false,
		},
	},

	-- Linters
	{
		"rshkarin/mason-nvim-lint",
		dependencies = { "mason.nvim", "mfussenegger/nvim-lint" },
		opts = {
			ensure_installed = linters,
			automatic_installation = false,
		},
	},

	-- Debug adapters
	{
		"jay-babu/mason-nvim-dap.nvim",
		dependencies = { "mason.nvim", "mfussenegger/nvim-dap" },
		opts = {
			ensure_installed = dap_adapters,
			automatic_installation = false,
			handlers = {},
		},
	},
}
