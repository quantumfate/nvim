-- lua/plugins/lsp/mason.lua
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
    },

    -- LSP servers
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = { "mason.nvim" },
        opts = {
            ensure_installed = {
                "lua_ls",
                "pyright",
                "ts_ls",
                "rust_analyzer",
                "gopls",
            },
            automatic_installation = true,
        },
    },

    -- Formatters
    {
        "zapling/mason-conform.nvim",
        dependencies = { "mason.nvim", "stevearc/conform.nvim" },
        opts = {
            ensure_installed = {
                "stylua",
                "prettierd",
                "black",
                "ruff",
                "shfmt",
            },
            automatic_installation = true,
        },
    },

    -- Linters
    {
        "rshkarin/mason-nvim-lint",
        dependencies = { "mason.nvim", "mfussenegger/nvim-lint" },
        opts = {
            ensure_installed = {
                "ruff",
                "eslint_d",
                "shellcheck",
                "luacheck",
                "markdownlint",
                "yamllint",
                "hadolint",
            },
            automatic_installation = true,
        },
    },

    -- Debug adapters
    {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = { "mason.nvim", "mfussenegger/nvim-dap" },
        opts = {
            ensure_installed = {
                "python",
                "codelldb",
                "js",
            },
            automatic_installation = true,
            handlers = {},
        },
    },
}
