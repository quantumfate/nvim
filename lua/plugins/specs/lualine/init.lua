return {
    'nvim-lualine/lualine.nvim',
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        "catppuccin/nvim"
    },
    event = "VimEnter",
    opts = function()
        local highlights = require("plugins.specs.lualine.highlights")
        local color = require("plugins.specs.lualine.color")
        local lualine_components = require("plugins.specs.lualine.components")
        return {
            options = {
                always_divide_middle = true,
                always_show_tabline = true,
                -- lualine option configuration
                component_separators = {
                    left = highlights.CatppuccinOverlay2(
                        icons.ui.HollowDividerLeft
                    ),
                    right = highlights.CatppuccinOverlay2(
                        icons.ui.HollowDividerRight
                    ),
                },
                section_separators = {
                    left = icons.ui.BoldDividerLeft,
                    right = icons.ui.BoldArrowRight,
                },
                theme = color,
                disabled_filetypes = {
                    statusline = {
                        "alpha",
                        "dashboard",
                        "NvimTree",
                        "Outline",
                    },
                    winbar = {
                        "alpha",
                        "dashboard",
                        "NvimTree",
                        "Outline",
                    },

                },
                refresh = {
                    statusline = 1000,
                    tabline = 1000,
                    winbar = 1000,
                    refresh_time = 16, -- ~60fps
                    events = {
                        'WinEnter',
                        'BufEnter',
                        'BufWritePost',
                        'SessionLoadPost',
                        'FileChangedShellPost',
                        'VimResized',
                        'Filetype',
                        'CursorMoved',
                        'CursorMovedI',
                        'ModeChanged',
                    },
                },
                globalstatus = true,
            },
            sections = {
                lualine_a = {
                    lualine_components.mode,
                },
                lualine_b = {
                    lualine_components.branch,
                },
                lualine_c = {
                    lualine_components.diff,
                    --lualine_components.python_env,
                },
                lualine_x = {
                    --lualine_components.diagnostics,
                    --lualine_components.lsp,
                    --lualine_components.diagnostics_source,
                    --lualine_components.formatters_source,
                    --lualine_components.code_action_source,
                    --lualine_components.hover_source,
                    --lualine_components.copilot,
                    lualine_components.filetype,
                },
                lualine_y = {
                    lualine_components.location,
                },
                lualine_z = {
                    lualine_components.progress,
                },
            },
            inactive_sections = {
                lualine_a = {
                },
                lualine_b = {
                },
                lualine_c = {
                },
                lualine_x = {
                    lualine_components.filetype,
                },
                lualine_y = {

                    lualine_components.location,
                },
                lualine_z = {
                },
            },
            tabline = nil,
            winbar = {
                lualine_c = {
                    function()
                        print("hey")
                    end,
                    {
                        function()
                            return require("nvim-navic").get_location()
                        end,
                        cond = function()
                            return require("nvim-navic").is_available()
                        end
                    },
                }
            },
            extensions = {
                "aerial", "assistant", "avante", "chadtree", "ctrlspace", "fern", "fugitive", "fzf", "lazy", "man",
                "mason", "mundo", "neo-tree", "nerdtree", "nvim-dap-ui", "nvim-tree", "oil", "overseer", "quickfix",
                "symbols-outline", "toggleterm", "trouble" }
        }
    end,
}
