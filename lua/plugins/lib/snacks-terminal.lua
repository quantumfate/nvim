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
		-- `<leader>iT` lives in the dock (lua/features/workspace/dock.lua), which owns
		-- the bottom slot: the same key puts the terminal away, a different one swaps to
		-- diagnostics or the debugger, and the terminal keeps its shell either way.
	},
}
