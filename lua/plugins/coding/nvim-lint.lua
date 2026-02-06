-- lua/plugins/coding/nvim-lint.lua
return {
    "mfussenegger/nvim-lint",
    event = { "User FileOpened" },
    keys = {
        {
            "<leader>cl",
            function()
                require("lint").try_lint()
            end,
            desc = "Lint buffer",
        },
    },
    config = function()
        local lint = require("lint")

        lint.linters_by_ft = {
            python = {},
            javascript = { "eslint_d" },
            typescript = { "eslint_d" },
            javascriptreact = { "eslint_d" },
            typescriptreact = { "eslint_d" },
            lua = { "luacheck" },
            sh = { "shellcheck" },
            fish = { "fish" },
            markdown = { "markdownlint" },
            yaml = { "yamllint" },
            dockerfile = { "hadolint" },
            nix = { "nix" },
            rust = { "rust_analyzer" }
        }

        -- Lint on events
        vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
            group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
            callback = function()
                lint.try_lint()
            end,
        })
    end,
}
