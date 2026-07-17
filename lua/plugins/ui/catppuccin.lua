--- Catppuccin colorscheme (lazy.nvim spec) with custom highlights for floats,
--- Noice, Edgy, Trouble, DAP and Neo-tree.

return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	lazy = false,
	--- Applies the options and activates the colorscheme.
	config = function(_, opts)
		require("catppuccin").setup(opts)
		vim.cmd.colorscheme("catppuccin")
	end,
	build = ":CatppuccinCompile",
	opts = {
		flavour = "macchiato", -- latte, frappe, macchiato, mocha
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
		integrations = {
			neo_tree = true,
		},

		--- Palette-driven highlight overrides applied on every flavour.
		---@param colors table<string, string> Catppuccin palette by name
		custom_highlights = function(colors)
			return {
				NormalFloat = { bg = colors.base },
				FloatBorder = { fg = colors.mauve, bg = colors.base },
				BlinkCmpMenuBorder = { link = "FloatBorder" },

				BlinkCmpKindAvante = { fg = colors.mauve },
				BlinkCmpKindAvanteCmd = { fg = colors.mauve },
				BlinkCmpKindAvanteMention = { fg = colors.mauve },
				BlinkCmpKindAvanteShortcut = { fg = colors.mauve },

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

				-- Neo-tree, mauve accent
				NeoTreeNormal = { bg = colors.base },
				NeoTreeNormalNC = { bg = colors.base },
				NeoTreeWinSeparator = { fg = colors.mauve, bg = colors.base },
				NeoTreeBorder = { fg = colors.mauve, bg = colors.base },
				NeoTreeTitleBar = { fg = colors.crust, bg = colors.mauve },
				NeoTreeFloatBorder = { link = "FloatBorder" },
				NeoTreeFloatTitle = { fg = colors.mauve, bg = colors.base },
				NeoTreeTabInactive = { fg = colors.overlay0, bg = colors.base },
				NeoTreeTabActive = { fg = colors.mauve, bg = colors.base, bold = true },
				NeoTreeTabSeparatorInactive = { fg = colors.overlay0, bg = colors.base },
				NeoTreeTabSeparatorActive = { fg = colors.mauve, bg = colors.base },

				-- Neo-tree file/folder icons and text
				NeoTreeDirectoryIcon = { fg = colors.mauve },
				NeoTreeDirectoryName = { fg = colors.mauve },
				NeoTreeFileName = { fg = colors.text },
				NeoTreeFileIcon = { fg = colors.blue },
				NeoTreeModified = { fg = colors.peach },
				NeoTreeHiddenByName = { fg = colors.overlay0 },

				-- Neo-tree git status
				NeoTreeGitAdded = { fg = colors.green },
				NeoTreeGitConflict = { fg = colors.red },
				NeoTreeGitDeleted = { fg = colors.red },
				NeoTreeGitIgnored = { fg = colors.overlay0 },
				NeoTreeGitModified = { fg = colors.yellow },
				NeoTreeGitUnstaged = { fg = colors.red },
				NeoTreeGitUntracked = { fg = colors.green },
				NeoTreeGitStaged = { fg = colors.green },

				-- Neo-tree symbols and UI elements
				NeoTreeSymbolicLinkTarget = { fg = colors.teal },
				NeoTreeRootName = { fg = colors.mauve, bold = true },
				NeoTreeIndentMarker = { fg = colors.overlay0 },
				NeoTreeExpander = { fg = colors.mauve },
				NeoTreeDimText = { fg = colors.overlay0 },

				-- Neo-tree window picker
				NeoTreeEndOfBuffer = { fg = colors.base },

				-- Neo-tree buffers source
				NeoTreeBufferNumber = { fg = colors.overlay1 },

				-- Neo-tree preview
				NeoTreePreview = { bg = colors.base },
				NeoTreeCursorLine = { bg = colors.surface0 },
			}
		end,
		--- Flavour-specific highlight overrides (macchiato only).
		highlight_overrides = {
			---@param colors table<string, string> Catppuccin palette by name
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
					NvimDapViewTabFill = { bg = colors.base },
					NvimDapViewTab = { fg = colors.overlay1, bg = colors.base },
					NvimDapViewTabSelected = { fg = colors.mauve },
				}
			end,
		},
	},
}
