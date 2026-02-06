-- lua/plugins/editor/treesitter.lua
return {
    {
        "nvim-treesitter/nvim-treesitter",
        version = false,
        build = ":TSUpdate",
        branch = "main",
        event = { "User FileOpened" },
        cmd = { "TSUpdate", "TSInstall", "TSUninstall" },
        opts = {
            ensure_installed = {
                "bash",
                "c",
                "diff",
                "html",
                "javascript",
                "jsdoc",
                "json",
                "lua",
                "luadoc",
                "luap",
                "markdown",
                "markdown_inline",
                "printf",
                "python",
                "query",
                "go",
                "rust",
                "cpp",
                "regex",
                "toml",
                "tsx",
                "typescript",
                "vim",
                "vimdoc",
                "xml",
                "yaml",
                "css",
                "latex",
                "norg",
                "scss",
                "svelte",
                "typst",
                "vue"
            },
            highlight = { enable = true },
            auto_install = true,
            indent = { enable = true },
        },
        config = function(_, opts)
            require("nvim-treesitter").setup(opts)
            -- install missing parsers (main branch)
            local ts = require("nvim-treesitter")
            local installed = ts.get_installed and ts.get_installed() or {}
            local to_install = vim.tbl_filter(function(lang)
                return not vim.tbl_contains(installed, lang)
            end, opts.ensure_installed or {})

            if #to_install > 0 then
                ts.install(to_install)
            end
            -- Start treesitter for all filetypes
            vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
                callback = function(ev)
                    pcall(vim.treesitter.start, ev.buf)
                end,
            })

            -- Also start for current buffer
            pcall(vim.treesitter.start)
        end,
    },

    -- Textobjects
    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        event = "BufReadPost",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        config = function()
            require("nvim-treesitter").setup({
                textobjects = {
                    select = {
                        enable = true,
                        lookahead = true,
                        keymaps = {
                            ["af"] = "@function.outer",
                            ["if"] = "@function.inner",
                            ["ac"] = "@class.outer",
                            ["ic"] = "@class.inner",
                            ["aa"] = "@parameter.outer",
                            ["ia"] = "@parameter.inner",
                        },
                    },
                    move = {
                        enable = true,
                        set_jumps = true,
                        goto_next_start = {
                            ["]f"] = "@function.outer",
                            ["]c"] = "@class.outer",
                            ["]a"] = "@parameter.inner",
                        },
                        goto_next_end = {
                            ["]F"] = "@function.outer",
                            ["]C"] = "@class.outer",
                            ["]A"] = "@parameter.inner",
                        },
                        goto_previous_start = {
                            ["[f"] = "@function.outer",
                            ["[c"] = "@class.outer",
                            ["[a"] = "@parameter.inner",
                        },
                        goto_previous_end = {
                            ["[F"] = "@function.outer",
                            ["[C"] = "@class.outer",
                            ["[A"] = "@parameter.inner",
                        },
                    },
                    swap = {
                        enable = true,
                        swap_next = {
                            ["<leader>a"] = "@parameter.inner",
                        },
                        swap_previous = {
                            ["<leader>A"] = "@parameter.inner",
                        },
                    },
                },
            })
        end,
    },

    -- Auto close HTML/JSX tags
    {
        "windwp/nvim-ts-autotag",
        event = "BufReadPost",
        opts = {},
    },
}
