local autocmds = {
  {
    "VimEnter",
    {
      group = "_general_settings",
      desc = "Disable terminal padding",
      callback = function()
        vim.fn.system(
          "kitty @ set-spacing padding=0 > /dev/null 2>&1"
        )
      end,
    },
  },
  {
    "VimLeave",
    {
      group = "_general_settings",
      desc = "Disable terminal padding",
      callback = function()
        vim.fn.system(
          "kitty @ set-spacing padding-left=15 padding-right=15 padding-top=20 padding-bottom=20 > /dev/null 2>&1"
        )
      end,
    },
  },
  {
    "ColorScheme",
    {
      group = "_qvim_colorscheme",
      callback = function()
        require("plugins.extra.nvim-navic").get_winbar()
        local colors = require("catppuccin.palettes").get_palette("macchiato")

        vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = colors.green })
        vim.api.nvim_set_hl(0, "CmpItemKindTabnine", { fg = colors.mauve })
        vim.api.nvim_set_hl(0, "CmpItemKindCrate", { fg = colors.peach })
        vim.api.nvim_set_hl(0, "CmpItemKindEmoji", { fg = colors.yellow })

        vim.api.nvim_set_hl(0, "CatppuccinRosewater", { fg = colors.rosewater })
        vim.api.nvim_set_hl(0, "CatppuccinFlamingo", { fg = colors.flamingo })
        vim.api.nvim_set_hl(0, "CatppuccinPink", { fg = colors.pink })
        vim.api.nvim_set_hl(0, "CatppuccinMauve", { fg = colors.mauve })
        vim.api.nvim_set_hl(0, "CatppuccinRed", { fg = colors.red })
        vim.api.nvim_set_hl(0, "CatppuccinMaroon", { fg = colors.maroon })
        vim.api.nvim_set_hl(0, "CatppuccinPeach", { fg = colors.peach })
        vim.api.nvim_set_hl(0, "CatppuccinYellow", { fg = colors.yellow })
        vim.api.nvim_set_hl(0, "CatppuccinGreen", { fg = colors.green })
        vim.api.nvim_set_hl(0, "CatppuccinTeal", { fg = colors.teal })
        vim.api.nvim_set_hl(0, "CatppuccinSky", { fg = colors.sky })
        vim.api.nvim_set_hl(0, "CatppuccinSapphire", { fg = colors.sapphire })
        vim.api.nvim_set_hl(0, "CatppuccinBlue", { fg = colors.blue })
        vim.api.nvim_set_hl(0, "CatppuccinLavender", { fg = colors.lavender })
        vim.api.nvim_set_hl(0, "CatppuccinText", { fg = colors.text })
        vim.api.nvim_set_hl(0, "CatppuccinSubtext1", { fg = colors.subtext1 })
        vim.api.nvim_set_hl(0, "CatppuccinSubtext0", { fg = colors.subtext0 })
        vim.api.nvim_set_hl(0, "CatppuccinOverlay2", { fg = colors.overlay2 })
        vim.api.nvim_set_hl(0, "CatppuccinOverlay1", { fg = colors.overlay1 })
        vim.api.nvim_set_hl(0, "CatppuccinOverlay0", { fg = colors.overlay0 })
        vim.api.nvim_set_hl(0, "CatppuccinSurface2", { fg = colors.surface2 })
        vim.api.nvim_set_hl(0, "CatppuccinSurface1", { fg = colors.surface1 })
        vim.api.nvim_set_hl(0, "CatppuccinSurface0", { fg = colors.surface0 })
        vim.api.nvim_set_hl(0, "CatppuccinBase", { fg = colors.base })
        vim.api.nvim_set_hl(0, "CatppuccinMantle", { fg = colors.mantle })
        vim.api.nvim_set_hl(0, "CatppuccinCrust", { fg = colors.crust })
      end,
    },
  },
}
for _, entry in ipairs(autocmds) do
  local event = entry[1]
  local opts = entry[2]
  if type(opts.group) == "string" and opts.group ~= "" then
    local exists, _ =
        pcall(vim.api.nvim_get_autocmds, { group = opts.group })
    if not exists then
      vim.api.nvim_create_augroup(opts.group, {})
    end
  end
  vim.api.nvim_create_autocmd(event, opts)
end
