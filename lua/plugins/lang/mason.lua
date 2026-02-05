local lsp_servers = { "lua_ls", "pyright", "ts_ls", "rust_analyzer", "gopls" }
local formatters = { "stylua", "prettierd", "black", "ruff", "shfmt" }
local linters = { "ruff", "eslint_d", "shellcheck", "luacheck", "markdownlint", "yamllint", "hadolint" }
local dap_adapters = { "python", "codelldb", "js" }

return {
    -- Mason: Package manager
    {
        "williamboman/mason.nvim",
        cmd = "Mason",
        keys = {
            { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" },
        },
        build = ":MasonUpdate",
        opts = {
            ui = {
                border = "rounded",
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
