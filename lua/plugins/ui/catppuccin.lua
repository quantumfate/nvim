--- Catppuccin colorscheme. The default scheme, so it is the one that loads at
--- startup; every other scheme is lazy and pulled in by :Theme. This config's own
--- highlight overrides are not here — see lua/theme/.

return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	lazy = false,
	--- Applies the options and activates the colorscheme.
	--- Applies the options, then the remembered scheme. Falls back to catppuccin when
	--- nothing is remembered or the remembered one no longer exists.
	config = function(_, opts)
		require("catppuccin").setup(opts)
		local theme = require("theme")
		local saved = theme.saved()
		if not (saved and theme.set(saved, { persist = false })) then
			vim.cmd.colorscheme("catppuccin")
		end
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
		-- Left off deliberately: auto-detection walks every entry in the lazy spec at
		-- startup to guess which integrations to enable. The list below is that answer,
		-- written down once.
		auto_integrations = false,
		integrations = {
			blink_cmp = true,
			dap = true,
			dap_ui = true,
			gitsigns = true,
			harpoon = true,
			indent_blankline = { enabled = false },
			lsp_trouble = true,
			markdown = true,
			mini = { enabled = true },
			navic = { enabled = true, custom_bg = "NONE" },
			neo_tree = true,
			neotest = true,
			noice = true,
			notify = true,
			nvim_surround = true,
			render_markdown = true,
			snacks = { enabled = true },
			treesitter = true,
			treesitter_context = true,
			ufo = true,
			which_key = true,
		},

		-- custom_highlights and highlight_overrides used to live here. They are now
		-- lua/theme/highlights.lua, written against role names instead of catppuccin's
		-- palette and re-applied by a ColorScheme autocmd, so they survive a switch to
		-- any other scheme instead of disappearing with this one.
		custom_highlights = {},
	},
}
