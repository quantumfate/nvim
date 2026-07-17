--- Modern completion engine with LSP integration and capability awareness
--- Provides intelligent completion with context-aware source selection
---@class plugins.coding.blink
---@field setup fun(): nil

---@class BlinkCompletionConfig
---@field menu table Menu display configuration
---@field documentation table Documentation window settings
---@field draw table Custom drawing components
---@field list table Selection and insertion behavior

---@class BlinkSourceConfig
---@field default string[] List of default completion sources
---@field providers table<string, BlinkProviderConfig> Source-specific configurations

---@class BlinkProviderConfig
---@field name string Human-readable provider name
---@field module? string Lua module path for the provider
---@field score_offset? number Priority adjustment for completions
---@field opts? table Provider-specific options

return {
	"saghen/blink.cmp",
	-- optional: provides snippets for the snippet source
	dependencies = {
		"saghen/blink.lib",
		"rafamadriz/friendly-snippets",
		{
			"L3MON4D3/LuaSnip",
			--, version = "v2.*"
		},
	},
	build = "cargo build --release",
	event = { "CmdlineEnter", "User FileOpened" },
	version = "1.*",

	opts = {
		keymap = {
			preset = "none",
			--- Order of "select_next" and "snippet_forward" is really important
			--- as it fixes tab annoyances with the completion menu and snippet templates
			["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
			["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
			["<CR>"] = { "accept", "fallback" },
			["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
			["<C-e>"] = { "cancel", "fallback" },
			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
		},
		cmdline = {
			keymap = {
				preset = "cmdline",
				["<Tab>"] = { "select_next", "show", "fallback" },
				["<S-Tab>"] = { "select_prev", "show", "fallback" },
				["<CR>"] = { "fallback" },
				["<space>"] = { "accept", "fallback" },
				["<C-CR>"] = { "accept", "fallback" },
				["<C-e>"] = { "cancel", "fallback" },
			},
			completion = {
				menu = {
					auto_show = function(ctx)
						return vim.fn.getcmdtype() == ":" or vim.fn.getcmdtype() == "@"
					end,
				},
				ghost_text = { enabled = true },
			},
		},
		appearance = {
			nerd_font_variant = "mono",
		},

		snippets = { preset = "luasnip" },
		sources = {
			default = { "lazydev", "lsp", "path", "snippets", "buffer" }, --avante
			providers = {
				lazydev = {
					name = "LazyDev",
					module = "lazydev.integrations.blink",
					-- make lazydev completions top priority (see `:h blink.cmp`)
					score_offset = 100,
				},
				snippets = {
					--- Hide snippets after trigger character
					should_show_items = function(ctx)
						return ctx.trigger.initial_kind ~= "trigger_character"
					end,
				},
				path = {
					opts = {
						--- Anchor path completion at the project root, not the buffer's directory.
						get_cwd = function(_)
							return require("util.root").get()
						end,
					},
				},
			},
		},
		completion = {
			menu = {
				border = "single",
				draw = {
					components = {
						-- Kind-icon column: swap in a color swatch for LSP color items.
						kind_icon = {
							--- Swatch for LSP color items, else the normal kind icon.
							text = function(ctx)
								local icon = ctx.kind_icon
								if ctx.item.source_name == "LSP" then
									local color_item = require("nvim-highlight-colors").format(
										ctx.item.documentation,
										{ kind = ctx.kind }
									)
									if color_item and color_item.abbr ~= "" then
										icon = color_item.abbr
									end
								end
								return icon .. ctx.icon_gap
							end,
							--- Derived color group for LSP color items, else the kind's group.
							highlight = function(ctx)
								local highlight = "BlinkCmpKind" .. ctx.kind
								if ctx.item.source_name == "LSP" then
									local color_item = require("nvim-highlight-colors").format(
										ctx.item.documentation,
										{ kind = ctx.kind }
									)
									if color_item and color_item.abbr_hl_group then
										highlight = color_item.abbr_hl_group
									end
								end
								return highlight
							end,
						},
					},
				},
			},
			documentation = {
				window = { border = "single" },
				auto_show = true,
			},
			list = {
				selection = { preselect = true, auto_insert = true },
			},
		},
		signature = { window = { border = "single" } },
		fuzzy = { implementation = "prefer_rust_with_warning" },
	},
	opts_extend = { "sources.default" },
}
