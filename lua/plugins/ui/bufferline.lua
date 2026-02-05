return {
    "akinsho/bufferline.nvim",
    event = "BufEnter",
    dependencies = { "nvim-tree/nvim-web-devicons", "nvim-mini/mini.nvim" },
    config = function(_, opts)
        opts.highlights = require("catppuccin.special.bufferline").get_theme()
        require("bufferline").setup(opts)
    end,
    opts =
    {
        options = {
            -- stylua: ignore
            close_command = function(n) Snacks.bufdelete(n) end,
            -- stylua: ignore
            right_mouse_command = function(n) Snacks.bufdelete(n) end,
            diagnostics = "nvim_lsp",
            always_show_bufferline = false,
            diagnostics_indicator = function(_, _, diag)
                local icons = icons.diagnostics
                local ret = (diag.error and icons.Error .. diag.error .. " " or "")
                    .. (diag.warning and icons.Warning .. diag.warning or "")
                return vim.trim(ret)
            end,
            offsets = {
                {
                    filetype = "neo-tree",
                    text = "Neo-tree",
                    highlight = "Directory",
                    text_align = "left",
                },
                {
                    filetype = "snacks_layout_box",
                },
            },
            get_element_icon = function(opts)
                -- stylua: ignore
                return require("mini.icons").get("filetype", opts.filetype)
            end,
        },
    },
}
