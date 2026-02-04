require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  checker = { enabled = true }, -- automatic updates
})

vim.cmd.colorscheme "catppuccin"
