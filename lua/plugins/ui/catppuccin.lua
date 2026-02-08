return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	lazy = false,
	config = function(_, opts)
		require("catppuccin").setup(opts)
		vim.cmd.colorscheme("catppuccin")
	end,
	build = ":CatppuccinCompile",
	opts = {
		-- catpuccin option configuration
		flavour = "macchiato", -- latte, frappe, macchiato, macchiato
		background = { -- :h background
			light = "latte",
			dark = "macchiato",
		},
		transparent_background = false, -- disables setting the background color.
		show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
		term_colors = false, -- sets terminal colors (e.g. `g:terminal_color_0`)
		dim_inactive = {
			enabled = false, -- dims the background color of inactive window
			shade = "dark",
			percentage = 0.15, -- percentage of the shade to apply to the inactive window
		},
		no_italic = false, -- Force no italic
		no_bold = false, -- Force no bold
		no_underline = false, -- Force no underline
		styles = { -- Handles the styles of general hi groups (see `:h highlight-args`):
			comments = { "italic" }, -- Change the style of comments
			conditionals = { "italic" },
			loops = {},
			functions = {},
			keywords = {},
			strings = {},
			variables = {},
			numbers = {},
			booleans = {},
			properties = {},
			types = {},
			operators = {},
		},
		color_overrides = {},
		default_integrations = true,
		auto_integrations = true,

		custom_highlights = function(colors)
			return {
				NormalFloat = { bg = colors.base },
				FloatBorder = { fg = colors.mauve, bg = colors.base },
				BlinkCmpMenuBorder = { link = "FloatBorder" },
				-- Noice cmdline
				NoiceCmdline = { bg = colors.base },
				NoiceCmdlinePopup = { bg = colors.base },
				NoiceCmdlinePopupBorder = { fg = colors.mauve, bg = colors.base },
				NoiceCmdlineIcon = { fg = colors.mauve, bg = colors.base },
				-- Noice other elements (if needed)
				NoicePopup = { bg = colors.base },
				NoicePopupBorder = { fg = colors.mauve, bg = colors.base },
				NoiceMini = { bg = colors.base },
				NoiceConfirm = { bg = colors.base },
				NoiceConfirmBorder = { fg = colors.mauve, bg = colors.base },
			}
		end,
		highlight_overrides = {
			macchiato = function(colors)
				return {
					Pmenu = { fg = colors.mauve, bg = colors.base },
					PmenuSel = { bg = colors.mauve, fg = colors.crust },
					PmenuThumb = { bg = colors.mauve },
					PmenuSbar = { fg = colors.mauve, bg = colors.mauve },
				}
			end,
		},
	},
}
