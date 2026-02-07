local modules = require("util.modules")

return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	event = "VimEnter",
	config = function(_, otps)
		require("catppuccin").setup(otps)
		vim.cmd.colorscheme "catppuccin"
	end,
	build = ":CatppuccinCompile",
	opts = {
		-- catpuccin option configuration
		flavour = "macchiato", -- latte, frappe, macchiato, macchiato
		background = {   -- :h background
			light = "latte",
			dark = "macchiato",
		},
		transparent_background = false, -- disables setting the background color.
		show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
		term_colors = false,      -- sets terminal colors (e.g. `g:terminal_color_0`)
		dim_inactive = {
			enabled = false,      -- dims the background color of inactive window
			shade = "dark",
			percentage = 0.15,    -- percentage of the shade to apply to the inactive window
		},
		no_italic = false,        -- Force no italic
		no_bold = false,          -- Force no bold
		no_underline = false,     -- Force no underline
		styles = {                -- Handles the styles of general hi groups (see `:h highlight-args`):
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
		integrations = {
			nvimtree = true,
			telescope = {
				enabled = true,
			},
			notify = true,
			alpha = true,
			gitsigns = true,
			hop = true,
			indent_blankline = {
				enabled = true,
				colored_indent_levels = true,
			},
			noice = true,
			flash = true,
			markdown = true,
			mason = true,
			neotest = true,
			neogit = true,
			cmp = true,
			dap = true,
			enable_ui = true,
			native_lsp = {
				enabled = true,
				virtual_text = {
					errors = { "italic" },
					hints = { "italic" },
					warnings = { "italic" },
					information = { "italic" },
				},
				underlines = {
					errors = { "underline" },
					hints = { "underline" },
					warnings = { "underline" },
					information = { "underline" },
				},
				inlay_hints = {
					background = true,
				},
			},
			navic = {
				enabled = true,
				custom_bg = "NONE",
			},
			treesitter_context = true,
			treesitter = true,
			which_key = true,
			illuminate = true,
			barbecue = {
				dim_dirname = true, -- directory name is dimmed by default
				bold_basename = true,
				dim_context = false,
				alt_background = false,
			},
			snacks = { enabled = true },
			mini = { enabled = true },
			-- For more plugins integrations please scroll down (https://github.com/catppuccin/nvim#integrations)
		},
		custom_highlights = function(colors)
			local ucolors = modules.require_on_index("catppuccin.utils.colors")
			local macchiato = require("catppuccin.palettes").get_palette("macchiato")
			return {
				---- Cmp Menu
				--PmenuSel = {
				--	fg = colors.base,
				--	bg = colors.maroon,
				--	style = { "bold" },
				--},
				---- Telescope
				--TelescopeBorder = { fg = colors.blue },
				--TelescopeSelectionCaret = { fg = colors.flamingo },
				--TelescopeSelection = {
				--	fg = colors.text,
				--	bg = colors.surface0,
				--	style = { "bold" },
				--},
				--TelescopeMatching = { fg = colors.blue },
				--TelescopePromptPrefix = {
				--	fg = colors.yellow,
				--	bg = colors.crust,
				--},
				--TelescopePromptNormal = { bg = colors.crust },
				--TelescopeResultsNormal = { bg = colors.mantle },
				--TelescopePreviewNormal = { bg = colors.crust },
				--TelescopePromptBorder = { bg = colors.crust, fg = colors.crust },
				--TelescopeResultsBorder = {
				--	bg = colors.mantle,
				--	fg = colors.mantle,
				--},
				--TelescopePreviewBorder = {
				--	bg = colors.crust,
				--	fg = colors.crust,
				--},
				--TelescopePromptTitle = { fg = colors.crust, bg = colors.mauve },
				--TelescopeResultsTitle = { fg = colors.crust, bg = colors.mauve },
				--TelescopePreviewTitle = { fg = colors.crust, bg = colors.mauve },
				---- Bufferline
				--BufferLineIndicatorSelected = { fg = colors.mauve },
				--BufferLineIndicator = { fg = colors.base },
				--BufferLineModifiedSelected = { fg = colors.peach },
				---- Cursorline & Linenumbers
				--CursorLine = { bg = colors.mantle },
				---- Visual Mode
				--Visual = {
				--	bg = ucolors.darken("#9745be", 0.25, macchiato.mantle),
				--	style = { "italic" },
				--},
			}
		end,
		highlight_overrides = {
			---@return table
			all = function(colors)
				return {
					NormalFloat = { bg = colors.green }, -- or colors.base, colors.crust
					FloatBorder = { fg = colors.mauve, bg = colors.green },

					---- borders
					--LspInfoBorder = { link = "FloatBorder" },
					--NvimTreeWinSeparator = { link = "FloatBorder" },
					WhichKeyBorder = { fg = colors.mauve },
					---- telescope
					--TelescopeBorder = { link = "FloatBorder" },
					--TelescopeTitle = { fg = colors.text },
					--TelescopeSelection = { link = "Selection" },
					--TelescopeSelectionCaret = { link = "Selection" },
					---- bufferline
					--BufferLineTabSeparator = { link = "FloatBorder" },
					--BufferLineSeparator = { link = "FloatBorder" },
					--BufferLineOffsetSeparator = { link = "FloatBorder" },
					----
					--FidgetTitle = { fg = colors.subtext1 },
					--FidgetTask = { fg = colors.subtext0 },
					---- Float windows (noice, hover, etc.)

				}
			end,
		},
	}
}
