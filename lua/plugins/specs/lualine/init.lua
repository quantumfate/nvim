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
                -- lualine option configuration
                component_separators = {
                    left = highlights.CatppuccinOverlay2(
                        icons.misc.Stars
                    ),
                    right = highlights.CatppuccinOverlay2(
                        icons.misc.Stars
                    ),
                },
                section_separators = {
                    left = icons.ui.BoldCircleDividerLeft,
                    right = icons.ui.BoldCircleDividerRight,
                },
                theme = color,
                disabled_filetypes = {
                    statusline = { "alpha" },
                    "dashboard",
                    "NvimTree",
                    "Outline",
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
                    lualine_components.python_env,
                },
                lualine_x = {
                    lualine_components.diagnostics,
                    lualine_components.lsp,
                    lualine_components.diagnostics_source,
                    lualine_components.formatters_source,
                    lualine_components.code_action_source,
                    lualine_components.hover_source,
                    lualine_components.copilot,
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
                    lualine_components.mode,
                },
                lualine_b = {
                    lualine_components.branch,
                },
                lualine_c = {
                    lualine_components.diff,
                    lualine_components.python_env,
                },
                lualine_x = {
                    lualine_components.diagnostics,
                    lualine_components.lsp,
                    lualine_components.diagnostics_source,
                    lualine_components.formatters_source,
                    lualine_components.code_action_source,
                    lualine_components.hover_source,
                    lualine_components.copilot,
                    lualine_components.filetype,
                },
                lualine_y = {

                    lualine_components.location,
                },
                lualine_z = {
                    lualine_components.progress,
                },
                tabline = nil,
                extensions = nil,
            }
        }
    end,
}
