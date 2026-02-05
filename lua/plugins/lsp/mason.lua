-- lua/plugins/lsp/mason.lua
return {
    { "williamboman/mason.nvim", opts = {} },

    -- LSP servers
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = { "mason.nvim" },
        opts = {
            ensure_installed = { "lua_ls", "pyright", "ts_ls" },
            automatic_installation = true,
        },
    },

    -- Linters
    {
        "rshkarin/mason-nvim-lint",
        dependencies = { "mason.nvim", "mfussenegger/nvim-lint" },
        opts = {
            ensure_installed = { "ruff", "eslint_d", "shellcheck" },
            automatic_installation = true,
        },
    },

    -- Formatters
    {
        "zapling/mason-conform.nvim",
        dependencies = { "mason.nvim", "stevearc/conform.nvim" },
        opts = {
            ensure_installed = { "stylua", "prettierd", "ruff_format", "shfmt" },
            automatic_installation = true,
        },
    },

    -- Debug adapters
    {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = { "mason.nvim", "mfussenegger/nvim-dap" },
        opts = {
            ensure_installed = { "python", "codelldb", "js" },
            automatic_installation = true,
            handlers = {}, -- auto-setup adapters
        },
    },
}
