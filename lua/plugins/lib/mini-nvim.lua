return {
    'nvim-mini/mini.nvim',
    version = false, -- use latest
    lazy = false,
    priority = 1000, -- load early since other plugins depend on icons
    config = function()
        -- Setup mini.icons first (other plugins may depend on it)
        require("mini.icons").setup({
            -- Icon style: 'glyph' or 'ascii'
            style = "glyph",

            -- Customize per category if needed
            -- default   = {},
            -- directory = {},
            -- extension = {},
            -- file      = {},
            -- filetype  = {},
            -- lsp       = {},
            -- os        = {},
        })

        -- Mock nvim-web-devicons so other plugins use mini.icons
        -- This makes plugins that depend on nvim-web-devicons work with mini.icons
        MiniIcons.mock_nvim_web_devicons()

        -- Tweak LSP kind to show icons (prepend icons to completion items)
        -- Using vim.schedule to avoid loading vim.lsp on startup
        vim.schedule(function()
            MiniIcons.tweak_lsp_kind("prepend") -- or "append" or "replace"
        end)

        -- Add any other mini modules you want to use below:

        -- Example: mini.pairs for auto-pairs
        -- require("mini.pairs").setup()

        -- Example: mini.surround for surround operations
        -- require("mini.surround").setup()

        -- Example: mini.comment for commenting
        -- require("mini.comment").setup()

        -- Example: mini.statusline (alternative to lualine)
        -- require("mini.statusline").setup()

        -- Example: mini.tabline (alternative to bufferline)
        -- require("mini.tabline").setup()

        -- Example: mini.files (file explorer)
        -- require("mini.files").setup()

        -- Example: mini.pick (fuzzy finder, alternative to telescope)
        -- require("mini.pick").setup()
    end,
}
