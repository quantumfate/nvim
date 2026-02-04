return {
    -- LSP Configuration
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
        },
        event = { "BufReadPre", "BufNewFile" },

        config = function()
            -- Setup Mason first
            require("mason").setup()
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "lua_ls", -- Lua
                    "pyright", -- Python
                    "ts_ls", -- TypeScript/JavaScript
                    "rust_analyzer", -- Rust
                    "gopls", -- Go
                },
                automatic_installation = true,
            })

            -- Get capabilities from nvim-cmp (if you have it)
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            -- Uncomment if you have nvim-cmp:
            -- capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

            -- Setup keymaps on LSP attach
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("lsp_attach", { clear = true }),
                callback = function(event)
                    local map = function(keys, func, desc)
                        vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
                    end

                    -- Jump to definition/references
                    map("gd", vim.lsp.buf.definition, "Goto Definition")
                    map("gr", vim.lsp.buf.references, "Goto References")
                    map("gI", vim.lsp.buf.implementation, "Goto Implementation")
                    map("gy", vim.lsp.buf.type_definition, "Type Definition")

                    -- Symbols (remove telescope if you don't have it)
                    -- map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "Document Symbols")
                    -- map("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "Workspace Symbols")

                    -- Actions
                    map("<leader>cr", vim.lsp.buf.rename, "Rename")
                    map("<leader>ca", vim.lsp.buf.code_action, "Code Action")

                    -- Hover/Help
                    map("K", vim.lsp.buf.hover, "Hover Documentation")
                    map("gK", vim.lsp.buf.signature_help, "Signature Help")

                    -- Diagnostics
                    map("<leader>cd", vim.diagnostic.open_float, "Line Diagnostics")
                    map("]d", vim.diagnostic.goto_next, "Next Diagnostic")
                    map("[d", vim.diagnostic.goto_prev, "Prev Diagnostic")
                end,
            })

            -- Configure diagnostics
            vim.diagnostic.config({
                underline = true,
                update_in_insert = false,
                virtual_text = {
                    spacing = 4,
                    prefix = "●",
                },
                severity_sort = true,
                float = {
                    border = "rounded",
                    source = "always",
                },
            })

            -- NEW API: Setup individual language servers using vim.lsp.config

            -- Lua
            vim.lsp.config.lua_ls = {
                cmd = { "lua-language-server" },
                filetypes = { "lua" },
                root_markers = { ".luarc.json", ".luarc.jsonc", ".luacheckrc", ".stylua.toml", "stylua.toml", "selene.toml", "selene.yml", ".git" },
                settings = {
                    Lua = {
                        runtime = { version = "LuaJIT" },
                        workspace = {
                            checkThirdParty = false,
                            library = {
                                vim.env.VIMRUNTIME,
                            },
                        },
                        telemetry = { enable = false },
                        diagnostics = {
                            globals = { "vim" },
                        },
                    },
                },
            }

            -- Python
            vim.lsp.config.pyright = {
                cmd = { "pyright-langserver", "--stdio" },
                filetypes = { "python" },
                root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile", ".git" },
            }

            -- TypeScript/JavaScript
            vim.lsp.config.ts_ls = {
                cmd = { "typescript-language-server", "--stdio" },
                filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
                root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
            }

            -- Rust
            vim.lsp.config.rust_analyzer = {
                cmd = { "rust-analyzer" },
                filetypes = { "rust" },
                root_markers = { "Cargo.toml", "rust-project.json" },
                settings = {
                    ["rust-analyzer"] = {
                        cargo = {
                            allFeatures = true,
                        },
                        checkOnSave = {
                            command = "clippy",
                        },
                    },
                },
            }

            -- Go
            vim.lsp.config.gopls = {
                cmd = { "gopls" },
                filetypes = { "go", "gomod", "gowork", "gotmpl" },
                root_markers = { "go.work", "go.mod", ".git" },
            }

            -- Enable the configured servers
            vim.lsp.enable({ "lua_ls", "pyright", "ts_ls", "rust_analyzer", "gopls" })
        end,
    },

    -- Mason UI
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

    {
        "williamboman/mason-lspconfig.nvim",
        lazy = true,
    },
}
