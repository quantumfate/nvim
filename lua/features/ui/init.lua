--- Internal UI and UX library providing unified slot management, mutually exclusive
--- sidebars, modal keymap profiles, and layout state snapshots.
---@class ui
local M = {}

M.slot = require("features.ui.slot")
M.sidebar = require("features.ui.sidebar")
M.mode = require("features.ui.mode")
M.layout = require("features.ui.layout")

--- Focuses the window to the left, with edge awareness.
--- If jumping left hits the sidebar edge, directly focuses the active sidebar window.
function M.focus_left()
	local cur_win = vim.api.nvim_get_current_win()
	vim.cmd("wincmd h")
	local new_win = vim.api.nvim_get_current_win()
	if new_win == cur_win then
		M.sidebar.focus()
	end
end

--- Initializes the UI library and default profiles (e.g. debug mode).
function M.setup()
	-- Register default debug modal profile
	M.mode.register({
		name = "debug",
		keymaps = {
			["c"] = {
				rhs = function()
					pcall(function()
						require("dap").continue()
					end)
				end,
				desc = "DAP: Continue",
			},
			["n"] = {
				rhs = function()
					pcall(function()
						require("dap").step_over()
					end)
				end,
				desc = "DAP: Step over",
			},
			["s"] = {
				rhs = function()
					pcall(function()
						require("dap").step_into()
					end)
				end,
				desc = "DAP: Step into",
			},
			["o"] = {
				rhs = function()
					pcall(function()
						require("dap").step_out()
					end)
				end,
				desc = "DAP: Step out",
			},
			["b"] = {
				rhs = function()
					pcall(function()
						require("dap").toggle_breakpoint()
					end)
				end,
				desc = "DAP: Toggle breakpoint",
			},
			["q"] = {
				rhs = function()
					M.mode.exit()
				end,
				desc = "Exit debug mode",
			},
		},
		on_enter = function()
			M.layout.to_debug()
			Snacks.notify.info("Debug mode: [c]ont, [n]ext, [s]tep, [b]reak, [q]uit", { title = "Debug" })
		end,
		on_exit = function()
			M.layout.to_code()
			Snacks.notify.info("Restored code layout", { title = "Debug" })
		end,
	})
end

return M
