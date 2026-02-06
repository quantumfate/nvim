-- lua/plugins/lsp/lspconfig.lua
return {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        "mason.nvim",
        "mason-lspconfig.nvim",
    },
    config = function()
        -- Keymaps on LSP attach
        vim.api.nvim_create_autocmd("LspAttach", {
            group = vim.api.nvim_create_augroup("lsp_attach", { clear = true }),
            callback = function(event)
                local map = function(keys, func, desc)
                    vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
                end

                map("gI", vim.lsp.buf.implementation, "Goto Implementation")
                map("gy", vim.lsp.buf.type_definition, "Type Definition")
                map("<leader>cr", vim.lsp.buf.rename, "Rename")
                map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
                map("K", vim.lsp.buf.hover, "Hover Documentation")
                map("gK", vim.lsp.buf.signature_help, "Signature Help")
                map("<leader>cd", vim.diagnostic.open_float, "Line Diagnostics")
                map("]d", vim.diagnostic.goto_next, "Next Diagnostic")
                map("[d", vim.diagnostic.goto_prev, "Prev Diagnostic")
            end,
        })

        -- Diagnostics config
        vim.diagnostic.config({
            underline = true,
            update_in_insert = true,
            virtual_text = {
                spacing = 4,
                prefix = "●",
            },
            severity_sort = true,
            float = {
                border = "rounded",
                source = "always",
            },
            signs = {
                text = {
                    [vim.diagnostic.severity.ERROR] = "",
                    [vim.diagnostic.severity.WARN] = "",
                    [vim.diagnostic.severity.HINT] = "",
                    [vim.diagnostic.severity.INFO] = "",
                },
            },
        })

        -- Server configurations
        vim.lsp.config.lua_ls = {
            cmd = { "lua-language-server" },
            filetypes = { "lua" },
            root_markers = { ".luarc.json", ".luarc.jsonc", ".luacheckrc", ".stylua.toml", "stylua.toml", ".git" },
            settings = {
                Lua = {
                    runtime = { version = "LuaJIT" },
                    workspace = {
                        checkThirdParty = false,
                        library = { vim.env.VIMRUNTIME },
                    },
                    telemetry = { enable = false },
                    diagnostics = { globals = { "vim" } },
                },
            },
        }

        -- CHANGED: basedpyright instead of pyright
        vim.lsp.config.basedpyright = {
            cmd = { "basedpyright-langserver", "--stdio" },
            filetypes = { "python" },
            root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile", ".git" },
            settings = {
                basedpyright = {
                    disableOrganizeImports = true, -- let ruff handle imports
                    analysis = {
                        diagnosticSeverityOverrides = {
                            reportUnusedImport = "none",
                            reportUnusedVariable = "none",
                            reportUnusedClass = "none",
                            reportUnusedFunction = "none",
                        },
                    },
                },
            },
        }

        vim.lsp.config.ts_ls = {
            cmd = { "typescript-language-server", "--stdio" },
            filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
            root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
        }

        vim.lsp.config.rust_analyzer = {
            cmd = { "rust-analyzer" },
            filetypes = { "rust" },
            root_markers = { "Cargo.toml", "rust-project.json" },
            settings = {
                ["rust-analyzer"] = {
                    cargo = { allFeatures = true },
                    checkOnSave = { command = "clippy" },
                },
            },
        }

        vim.lsp.config.gopls = {
            cmd = { "gopls" },
            filetypes = { "go", "gomod", "gowork", "gotmpl" },
            root_markers = { "go.work", "go.mod", ".git" },
        }

        vim.lsp.enable({ "lua_ls", "basedpyright", "ts_ls", "rust_analyzer", "gopls" })
    end,
}
