return {
    "lewis6991/gitsigns.nvim",
    event = "User FileOpened",
    cmd = "Gitsigns",
    opts = {
        on_attach = function(bufnr)
            local wk = require("which-key")
            wk.add({
                { "<leader>g",  buffer = bufnr,                                      group = "git" },
                { "<leader>gR", "<cmd>lua require 'gitsigns'.reset_buffer()<cr>",    buffer = bufnr, desc = "Reset Buffer" },
                { "<leader>gb", "<cmd>Telescope git_branches<cr>",                   buffer = bufnr, desc = "Checkout branch" },
                { "<leader>gc", "<cmd>Telescope git_commits<cr>",                    buffer = bufnr, desc = "Checkout commit" },
                { "<leader>gd", "<cmd>Gitsigns diffthis HEAD<cr>",                   buffer = bufnr, desc = "Diff" },
                { "<leader>gg", "<cmd>lua _LAZYGIT_TOGGLE()<CR>",                    buffer = bufnr, desc = "Lazygit" },
                { "<leader>gj", "<cmd>lua require 'gitsigns'.next_hunk()<cr>",       buffer = bufnr, desc = "Next Hunk" },
                { "<leader>gk", "<cmd>lua require 'gitsigns'.prev_hunk()<cr>",       buffer = bufnr, desc = "Prev Hunk" },
                { "<leader>gl", "<cmd>lua require 'gitsigns'.blame_line()<cr>",      buffer = bufnr, desc = "Blame" },
                { "<leader>go", "<cmd>Telescope git_status<cr>",                     buffer = bufnr, desc = "Open changed file" },
                { "<leader>gp", "<cmd>lua require 'gitsigns'.preview_hunk()<cr>",    buffer = bufnr, desc = "Preview Hunk" },
                { "<leader>gr", "<cmd>lua require 'gitsigns'.reset_hunk()<cr>",      buffer = bufnr, desc = "Reset Hunk" },
                { "<leader>gs", "<cmd>lua require 'gitsigns'.stage_hunk()<cr>",      buffer = bufnr, desc = "Stage Hunk" },
                { "<leader>gu", "<cmd>lua require 'gitsigns'.undo_stage_hunk()<cr>", buffer = bufnr, desc = "Undo Stage Hunk" },
            })
        end,
        -- gitsigns option configuration
        signs = {
            add = {
                hl = "GitSignsAdd",
                text = "▎",
                numhl = "GitSignsAddNr",
                linehl = "GitSignsAddLn",
            },
            change = {
                hl = "GitSignsChange",
                text = "▎",
                numhl = "GitSignsChangeNr",
                linehl = "GitSignsChangeLn",
            },
            delete = {
                hl = "GitSignsDelete",
                text = "契",
                numhl = "GitSignsDeleteNr",
                linehl = "GitSignsDeleteLn",
            },
            topdelete = {
                hl = "GitSignsDelete",
                text = "契",
                numhl = "GitSignsDeleteNr",
                linehl = "GitSignsDeleteLn",
            },
            changedelete = {
                hl = "GitSignsChange",
                text = "▎",
                numhl = "GitSignsChangeNr",
                linehl = "GitSignsChangeLn",
            },
        },
        signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
        numhl = false,     -- Toggle with `:Gitsigns toggle_numhl`
        linehl = false,    -- Toggle with `:Gitsigns toggle_linehl`
        word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
        watch_gitdir = {
            interval = 1000,
            follow_files = true,
        },
        attach_to_untracked = true,
        current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
        current_line_blame_opts = {
            virt_text = true,
            virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
            delay = 1000,
            ignore_whitespace = false,
        },
        current_line_blame_formatter_opts = {
            relative_time = false,
        },
        sign_priority = 6,
        update_debounce = 100,
        status_formatter = nil, -- Use default
        max_file_length = 40000,
        preview_config = {
            -- Options passed to nvim_open_win
            border = "single",
            style = "minimal",
            relative = "cursor",
            row = 0,
            col = 1,
        }

    }
}
