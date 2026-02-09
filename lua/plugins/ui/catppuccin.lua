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
				-- Edgy window backgrounds and borders
				EdgyNormal = { bg = colors.base },
				EdgyWinBar = { fg = colors.mauve, bg = colors.base, bold = true },
				EdgyWinBarInactive = { fg = colors.overlay0, bg = colors.base },
				EdgyTitle = { fg = colors.mauve, bg = colors.base, bold = true },
				EdgyTitleInactive = { fg = colors.overlay0, bg = colors.base },
				EdgyIcon = { fg = colors.mauve, bg = colors.base },
				EdgyIconActive = { fg = colors.mauve, bg = colors.base },

				-- Trouble backgrounds (for the edgy panels)
				TroubleNormal = { bg = colors.base },
				TroubleNormalNC = { bg = colors.base },
				TroubleTitle = { fg = colors.mauve },
				TroubleIconDirectory = { fg = colors.mauve },
				TroubleCount = { fg = colors.mauve, bg = colors.surface0 },

				-- Dap
				DapStoppedLine = { bg = colors.surface0 },
				DapUIScope = { fg = colors.mauve },
				DapUIType = { fg = colors.mauve },
				DapUIValue = { fg = colors.text },
				DapUIVariable = { fg = colors.text },
				DapUIModifiedValue = { fg = colors.peach, bold = true },

				-- Ufo
			}
		end,
		highlight_overrides = {
			macchiato = function(colors)
				return {
					Pmenu = { fg = colors.mauve, bg = colors.base },
					PmenuSel = { bg = colors.mauve, fg = colors.crust },
					PmenuThumb = { fg = colors.mauve, bg = colors.base },
					PmenuSbar = { fg = colors.mauve, bg = colors.base },

					Normal = { fg = colors.text, bg = colors.base },
					Special = { fg = colors.mauve, bg = colors.base },
					Visual = { bg = colors.surface0 },
					CursorLine = { bg = colors.base },
					Directory = { fg = colors.mauve },
					LineNr = { fg = colors.mauve },
					TroubleFilename = { fg = colors.mauve },
					Title = { fg = colors.mauve },

					MoreMsg = { fg = colors.teal },
				}
			end,
		},
	},
}
