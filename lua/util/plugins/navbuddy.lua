local navbuddy_actions = require("nvim-navbuddy.actions")

local M = {
	---Overwrites navbuddy's comment function to use neovims inbuilt comment
	---engine streamlined by treesitter and ts-comments.
	override_comment = function()
		-- do the original setup
		navbuddy_actions.comment()

		return {
			callback = function(display)
				-- Let original do the setup (fix_end_character_position, window switching, marks)
				-- But we intercept before it calls Comment.nvim

				-- Manually do what original does, but swap the comment part
				display.state.leaving_window_for_action = true
				vim.api.nvim_set_current_win(display.for_win)

				local start_line = display.focus_node.scope["start"].line
				local end_line = display.focus_node.scope["end"].line

				-- Use native commenting
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
	---Overwrites navbuddy's telescope function to call snacks instead
	---@param _opts table
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
