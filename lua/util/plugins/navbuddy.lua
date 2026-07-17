--- Custom nvim-navbuddy actions: native commenting and a Snacks-based picker.
---@class util.plugins.navbuddy
local navbuddy_actions = require("nvim-navbuddy.actions")

local M = {
	--- Action that comments the focused node's line range using Neovim's built-in engine.
	---@return table action_config { callback, description }
	override_comment = function()
		navbuddy_actions.comment()

		return {
			-- Replicates the original action's window handling, swapping in native commenting.
			callback = function(display)
				display.state.leaving_window_for_action = true
				vim.api.nvim_set_current_win(display.for_win)

				local start_line = display.focus_node.scope["start"].line
				local end_line = display.focus_node.scope["end"].line

				local ok, comment = pcall(require, "vim._comment")
				if ok and comment.toggle_lines then
					comment.toggle_lines(start_line, end_line)
				else
					vim.cmd(string.format("normal! %dGV%dGgc", start_line, end_line))
				end

				vim.api.nvim_set_current_win(display.mid.winid)
				display.state.leaving_window_for_action = false
			end,
			description = "Comment",
		}
	end,
	--- Action that opens navbuddy's picker via Snacks instead of telescope.
	---@param _opts table Picker options
	---@return table action_config { callback, description }
	override_telescope = function(_opts)
		return {
			callback = function(display)
				require("nvim-navbuddy.picker.snacks").find(_opts, display)
			end,
			description = "Snacks picker override.",
		}
	end,
}

M.__index = M

return M
