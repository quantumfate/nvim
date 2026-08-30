-- Core snacks.nvim spec: enables the feature set and wires debug globals on VeryLazy.

return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		bigfile = { enabled = true },
		explorer = { enabled = false },
		-- Indent guides: one thin rule per level, and the current scope one shade
		-- brighter. No chunk brackets and no animation — a guide that moves or
		-- draws corners is competing with the code for attention, and there are
		-- dozens of them on screen at once. Colours: SnacksIndent* in the
		-- catppuccin spec (surface0 / surface2).
		indent = {
			enabled = true,
			indent = { char = "▏", hl = "SnacksIndent" },
			scope = { enabled = true, char = "▏", hl = "SnacksIndentScope", underline = false },
			chunk = { enabled = false },
			animate = { enabled = false },
		},
		-- The one input widget in the editor: rename, create, grep prompts, and
		-- anything else calling vim.ui.input. Anchored at the cursor so the
		-- prompt appears where you are already looking.
		input = {
			enabled = true,
			icon = "",
			win = {
				relative = "cursor",
				row = -3,
				col = 0,
				border = "rounded",
				title_pos = "left",
			},
		},
		-- No backdrop. snacks dims the whole editor behind a float (style
		-- "float" defaults to backdrop = 60, an opaque overlay window at a lower
		-- zindex). Two reasons it goes: the terminal is already the only thing
		-- on screen, so "focus" needs no help; and the dim layer is what made
		-- the picker look like it was floating over a washed-out screenshot
		-- instead of over the editor.
		styles = {
			float = { backdrop = false },
		},
		picker = {
			enabled = true,
			-- Presets other than `sidebar` do not carry `backdrop = false`, and
			-- the layout wins over the style, so it is set here as well.
			layout = { layout = { backdrop = false } },
		},
		notifier = { enabled = true },
		quickfile = { enabled = true },
		bufdelete = { enabled = true },
		scope = { enabled = true },
		scroll = { enabled = true },
		statuscolumn = { enabled = true },
		words = { enabled = true },
		toggle = { enabled = true },
	},
	keys = {},
	--- On VeryLazy, install snacks-backed debug globals and route `:=`/print through them.
	---@return nil
	init = function()
		vim.api.nvim_create_autocmd("User", {
			pattern = "VeryLazy",
			callback = function()
				-- External globals: _G.dd/_G.bt are snacks-backed debug helpers used across the config.
				_G.dd = function(...)
					Snacks.debug.inspect(...)
				end
				_G.bt = function()
					Snacks.debug.backtrace()
				end

				-- Route the `:=` command / print through the inspector.
				if vim.fn.has("nvim-0.11") == 1 then
					vim._print = function(_, ...)
						dd(...)
					end
				else
					vim.print = _G.dd
				end
			end,
		})
	end,
}
