--- Custom nvim-navbuddy actions: native commenting and a Snacks-based picker.
---@class features.navbuddy
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

--- Opens navbuddy over the `aux` pane rather than the middle of the screen.
---
--- The default is a float at 60% of the editor, centred — which lands squarely on top
--- of the code it is describing. Since navbuddy re-reads `window` on every `setup`
--- call (user values win the merge), the geometry can be recomputed from wherever the
--- aux pane currently is and handed over just before opening.
---
--- If there is no aux pane, it falls back to the right half: still beside the code
--- rather than over it.
function M.open_in_aux()
	local workspace = require("features.workspace")
	-- The pane opposite the cursor, not the one named `aux`: launched from the right
	-- pane, `aux` *is* the cursor's window and navbuddy covered the code it describes.
	local current = vim.api.nvim_get_current_win()
	local win = workspace.lower(current)

	local geometry
	if win and vim.api.nvim_win_is_valid(win) then
		local pos = vim.api.nvim_win_get_position(win)
		geometry = {
			size = { height = vim.api.nvim_win_get_height(win), width = vim.api.nvim_win_get_width(win) },
			-- nui positions by the top-left corner when given absolute numbers.
			position = { row = pos[1], col = pos[2] },
		}
	else
		geometry = { size = { height = "80%", width = "48%" }, position = { row = "50%", col = "97%" } }
	end

	require("nvim-navbuddy").setup({ window = geometry })
	vim.cmd("Navbuddy")
end

return M
