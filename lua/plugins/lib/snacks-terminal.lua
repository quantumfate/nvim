-- snacks.terminal spec: stacked terminal with in-terminal keymaps and a cursor-restoring toggle.

-- Module-level mutable state: saved window/cursor position while the toggle terminal is open (nil when closed).
---@type table|nil
local old_cursor_pos = nil

return {
	"folke/snacks.nvim",
	opts = {
		terminal = {
			bo = {
				filetype = "snacks_terminal",
			},
			wo = {},
			stack = true, -- stack split windows sharing a position
			keys = {
				q = "hide",
				-- Opens the file path under the cursor, hiding the terminal first.
				gf = function(self)
					local f = vim.fn.findfile(vim.fn.expand("<cfile>"), "**")
					if f == "" then
						Snacks.notify.warn("No file under cursor")
					else
						self:hide()
						vim.schedule(function()
							vim.cmd("e " .. f)
						end)
					end
				end,
				term_normal = {
					"<esc>",
					-- Double-tap <esc> within 200ms to leave terminal mode; a single tap passes through.
					function(self)
						self.esc_timer = self.esc_timer or (vim.uv or vim.loop).new_timer()
						if self.esc_timer:is_active() then
							self.esc_timer:stop()
							vim.cmd("stopinsert")
						else
							self.esc_timer:start(200, 0, function() end)
							return "<esc>"
						end
					end,
					mode = "t",
					expr = true,
					desc = "Double escape to normal mode",
				},
			},
		},
	},
	keys = {
		{
			"<leader>iT",
			-- Toggles the terminal, saving the cursor on open and restoring it on close.
			function()
				local ui_util = require("util.ui")
				if old_cursor_pos then
					Snacks.terminal.toggle()
					ui_util.restore_win_and_cursor(old_cursor_pos)
					old_cursor_pos = nil
				else
					old_cursor_pos = ui_util.save_win_and_cursor()
					Snacks.terminal.toggle()
				end
			end,
			desc = "Toggle terminal",
		},
	},
}
