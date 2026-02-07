local get_gps = function()
	local status_gps_ok, gps = pcall(require, "nvim-navic")
	if not status_gps_ok then
		return ""
	end

	local status_ok, gps_location = pcall(gps.get_location, {})
	if not status_ok then
		return ""
	end

	if not gps.is_available() or gps_location == "error" then
		return ""
	end

	if not require("utils.fn").isempty(gps_location) then
		return "%#NavicSeparator#" .. icons.ui.ChevronRight .. "%* " .. gps_location
	else
		return ""
	end
end

local navbuddy_actions = require("nvim-navbuddy.actions")

local nvim_navic = {
	get_filename = function()
		local filename = vim.fn.expand("%:t")
		local extension = vim.fn.expand("%:e")
		local f = require("utils.fn")

		if not f.isempty(filename) then
			local file_icon, hl_group
			local devicons_ok, devicons = pcall(require, "mini.icons")
			if devicons_ok then
				file_icon, hl_group = devicons.get_icon(filename, extension, { default = true })

				if f.isempty(file_icon) then
					file_icon = icons.kind.File
				end
			else
				file_icon = ""
				hl_group = "Normal"
			end

			local buf_ft = vim.bo.filetype

			if buf_ft == "dapui_breakpoints" then
				file_icon = icons.ui.Bug
			end

			if buf_ft == "dapui_stacks" then
				file_icon = icons.ui.Stacks
			end

			if buf_ft == "dapui_scopes" then
				file_icon = icons.ui.Scopes
			end

			if buf_ft == "dapui_watches" then
				file_icon = icons.ui.Watches
			end

			if buf_ft == "dapui_console" then
				file_icon = icons.ui.DebugConsole
			end

			local navic_text = vim.api.nvim_get_hl_by_name("Normal", true)
			vim.api.nvim_set_hl(0, "Winbar", { fg = navic_text.foreground })

			return " " .. "%#" .. hl_group .. "#" .. file_icon .. "%*" .. " " .. "%#Winbar#" .. filename .. "%*"
		end
	end,
	---@param self any
	---@return boolean
	excludes = function(self)
		return vim.tbl_contains(self.winbar_filetype_exclude or {}, vim.bo.filetype)
	end,
	get_winbar = function(self)
		if self:excludes() then
			return
		end
		local f = require("utils.fn")
		local value = self.get_filename()

		local gps_added = false
		if not f.isempty(value) then
			local gps_value = get_gps()
			value = value .. " " .. gps_value
			if not f.isempty(gps_value) then
				gps_added = true
			end
		end

		if not f.isempty(value) and f.get_buf_option("mod") then
			local mod = "%#LspCodeLens#" .. icons.ui.Circle .. "%*"
			if gps_added then
				value = value .. " " .. mod
			else
				value = value .. mod
			end
		end

		local num_tabs = #vim.api.nvim_list_tabpages()

		if num_tabs > 1 and not f.isempty(value) then
			local tabpage_number = tostring(vim.api.nvim_tabpage_get_number(0))
			value = value .. "%=" .. tabpage_number .. "/" .. tostring(num_tabs)
		end

		local status_ok, _ = pcall(vim.api.nvim_set_option_value, "winbar", value, { scope = "local" })
		if not status_ok then
			return
		end
	end,
	create_winbar = function(self)
		vim.api.nvim_create_augroup("_winbar", {})
		vim.api.nvim_create_autocmd({
			"CursorHoldI",
			"CursorHold",
			"BufWinEnter",
			"BufFilePost",
			"InsertEnter",
			"BufWritePost",
			"TabClosed",
			"TabEnter",
		}, {
			group = "_winbar",
			callback = function()
				local status_ok, _ = pcall(vim.api.nvim_buf_get_var, 0, "lsp_floating_window")
				if not status_ok then
					require("util.plugins.nvim-navic"):get_winbar()
				end
			end,
		})
	end,
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
	override_telescope = function(_opts)
		return {
			callback = function(display)
				require("nvim-navbuddy.picker.snacks").find(_opts, display)
			end,
			description = "Snacks picker override.",
		}
	end,
}

nvim_navic.__index = nvim_navic

return nvim_navic
