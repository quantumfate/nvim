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
				-- Borders are structure, not accent. They sit one step off the
				-- background (surface1) so a float reads as a separate surface
				-- without drawing a bright frame around it; mauve is reserved
				-- for the one active thing on screen.
				FloatBorder = { fg = colors.surface1, bg = colors.base },
				FloatTitle = { fg = colors.overlay1, bg = colors.base },
				-- Splits get a real rule again: surface1 is one step off the
				-- background, enough to see where a docked panel starts and stops
				-- without framing the screen in colour.
				WinSeparator = { fg = colors.surface1, bg = colors.base },
				BlinkCmpMenuBorder = { link = "FloatBorder" },

				BlinkCmpKindAvante = { fg = colors.mauve },
				BlinkCmpKindAvanteCmd = { fg = colors.mauve },
				BlinkCmpKindAvanteMention = { fg = colors.mauve },
				BlinkCmpKindAvanteShortcut = { fg = colors.mauve },

				-- Noice cmdline
				NoiceCmdline = { bg = colors.base },
				NoiceCmdlinePopup = { bg = colors.base },
				NoiceCmdlinePopupBorder = { link = "FloatBorder" },
				NoiceCmdlineIcon = { fg = colors.mauve, bg = colors.base },
				-- Noice other elements (if needed)
				NoicePopup = { bg = colors.base },
				NoicePopupBorder = { link = "FloatBorder" },
				NoiceMini = { bg = colors.base },
				NoiceConfirm = { bg = colors.base },
				NoiceConfirmBorder = { link = "FloatBorder" },
				-- Edgy window backgrounds and borders
				EdgyNormal = { bg = colors.base },
				EdgyWinBar = { fg = colors.mauve, bg = colors.base, bold = true },
				EdgyWinBarInactive = { fg = colors.overlay0, bg = colors.base },
				EdgyTitle = { fg = colors.overlay1, bg = colors.base },
				EdgyTitleInactive = { fg = colors.overlay0, bg = colors.base },
				EdgyIcon = { fg = colors.overlay0, bg = colors.base },
				EdgyIconActive = { fg = colors.mauve, bg = colors.base },

				-- Trouble backgrounds (for the edgy panels)
				TroubleNormal = { bg = colors.base },
				TroubleNormalNC = { bg = colors.base },
				TroubleTitle = { fg = colors.mauve },
				TroubleIconDirectory = { fg = colors.mauve },
				TroubleCount = { fg = colors.mauve, bg = colors.surface0 },

				-- The statusline and tabline own no background: they sit on the
				-- editor background and are set off by whitespace, like the tmux
				-- bar above them. Nothing about them should read as a "bar".
				StatusLine = { bg = colors.base, fg = colors.overlay0 },
				StatusLineNC = { bg = colors.base, fg = colors.surface2 },
				TabLine = { bg = colors.base, fg = colors.overlay0 },
				TabLineFill = { bg = colors.base },
				TabLineSel = { bg = colors.base, fg = colors.mauve, bold = true },
				WinBar = { bg = colors.base, fg = colors.overlay0 },
				WinBarNC = { bg = colors.base, fg = colors.surface2 },

				-- lazy.nvim UI. Its groups are `hi default` links into whatever the
				-- colorscheme happens to define — IncSearch for the home button,
				-- Visual for the active tab, CursorLine for the others — which is
				-- how the manager ended up with filled chips and a rainbow of
				-- load-reason colours. Redefined here on the same three rules as
				-- everything else: no fills, one accent, metadata in greys.
				LazyNormal = { bg = colors.base, fg = colors.text },
				LazyH1 = { fg = colors.mauve, bg = colors.base, bold = true },
				LazyH2 = { fg = colors.subtext0, bold = true },
				LazyButton = { fg = colors.overlay0, bg = colors.base },
				LazyButtonActive = { fg = colors.mauve, bg = colors.base, bold = true },
				LazySpecial = { fg = colors.surface2 },
				LazyDimmed = { fg = colors.surface2 },
				LazyProp = { fg = colors.surface2 },
				LazyValue = { fg = colors.subtext0 },
				LazyComment = { fg = colors.overlay0 },
				LazyLocal = { fg = colors.overlay1 },
				LazyDir = { fg = colors.overlay1 },
				LazyUrl = { fg = colors.overlay1 },
				LazyNoCond = { fg = colors.overlay0 },
				LazyProgressDone = { fg = colors.mauve },
				LazyProgressTodo = { fg = colors.surface1 },
				LazyCommit = { fg = colors.overlay1 },
				LazyCommitIssue = { fg = colors.overlay1 },
				LazyCommitType = { fg = colors.subtext0, bold = true },
				LazyCommitScope = { fg = colors.overlay1, italic = true },

				-- Load reasons are metadata about metadata: one grey for all of
				-- them, so the plugin NAME is what the eye lands on in a list of
				-- seventy rows.
				LazyReasonCmd = { fg = colors.overlay0 },
				LazyReasonEvent = { fg = colors.overlay0 },
				LazyReasonFt = { fg = colors.overlay0 },
				LazyReasonImport = { fg = colors.overlay0 },
				LazyReasonKeys = { fg = colors.overlay0 },
				LazyReasonPlugin = { fg = colors.overlay0 },
				LazyReasonRequire = { fg = colors.overlay0 },
				LazyReasonRuntime = { fg = colors.overlay0 },
				LazyReasonSource = { fg = colors.overlay0 },
				LazyReasonStart = { fg = colors.overlay0 },

				-- snacks.input — same surfaces as every other float: quiet border,
				-- grey title, and the accent on the prompt icon alone, which is
				-- the one thing that says "type here".
				SnacksInputBorder = { link = "FloatBorder" },
				SnacksInputTitle = { fg = colors.overlay1, bg = colors.base },
				SnacksInputIcon = { fg = colors.mauve, bg = colors.base },
				SnacksInputNormal = { bg = colors.base, fg = colors.text },

				-- Indent guides (snacks.indent). The guide is a ruler: it must be
				-- visible when looked for and invisible when not. surface0 sits
				-- barely above the background; only the enclosing scope steps up
				-- to surface2, so exactly one guide on screen is brighter.
				SnacksIndent = { fg = colors.surface0 },
				SnacksIndentScope = { fg = colors.surface2 },
				SnacksIndentChunk = { fg = colors.surface2 },

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
				-- The tree is an edgy panel like the rest, so it carries the same
				-- quiet rule on its edge.
				NeoTreeWinSeparator = { link = "WinSeparator" },
				NeoTreeBorder = { link = "WinSeparator" },
				NeoTreeTitleBar = { fg = colors.overlay1, bg = colors.base },
				NeoTreeFloatBorder = { link = "FloatBorder" },
				NeoTreeFloatTitle = { fg = colors.mauve, bg = colors.base },
				NeoTreeTabInactive = { fg = colors.overlay0, bg = colors.base },
				NeoTreeTabActive = { fg = colors.mauve, bg = colors.base, bold = true },
				NeoTreeTabSeparatorInactive = { fg = colors.overlay0, bg = colors.base },
				NeoTreeTabSeparatorActive = { fg = colors.mauve, bg = colors.base },

				-- Neo-tree file/folder icons and text
				NeoTreeDirectoryIcon = { fg = colors.mauve },
				NeoTreeDirectoryName = { fg = colors.subtext0 },
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
				NeoTreeRootName = { fg = colors.overlay1, bold = true },
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
					-- Line numbers are a ruler, not content: they were mauve,
					-- which made the brightest colour on screen the one thing
					-- you never actually read. Only the cursor's line is accented.
					LineNr = { fg = colors.surface2 },
					CursorLineNr = { fg = colors.mauve, bold = true },
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
