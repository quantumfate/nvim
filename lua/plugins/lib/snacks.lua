-- Core snacks.nvim spec: enables the feature set and wires debug globals on VeryLazy.

return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		bigfile = { enabled = true },
		explorer = { enabled = false },
		indent = { enabled = true },
		input = { enabled = true },
		picker = { enabled = true },
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
