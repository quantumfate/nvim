local conditions = require("util.plugins.lualine.conditions")
local colors = require("util.plugins.lualine.color")
---@class lualine_highlights
local highlights = require("util.plugins.lualine.highlights")
local util = require("util.plugins.lualine.util")

local fmt = string.format

local function diff_source()
	local gitsigns = vim.b.gitsigns_status_dict
	if gitsigns then
		return {
			added = gitsigns.added,
			modified = gitsigns.changed,
			removed = gitsigns.removed,
		}
	end
end

local function gitsigns_head()
	local gitsigns = vim.b.gitsigns_status_dict
	if gitsigns then
		return gitsigns.head
	end
end
---@class lualine_components
---@field mode component
---@field branch component
---@field filename component
---@field diff component
---@field python_env component
---@field diagnostics component
---@field treesitter component
---@field lsp component
---@field copilot component
---@field location component
---@field progress component
---@field spaces component
---@field encoding component
---@field filetype component
---@field scrollbar component
---@field noice_recording component
return {
	mode = {
		"mode",
		padding = { left = 1, right = 1 },
		cond = nil,
		---@param displayed string
		---@param _ table
		fmt = function(displayed, _)
			return util.unified_format(displayed)
		end,
	},
	branch = {
		"branch",
		source = gitsigns_head,
		icon = icons.git.Branch,
		fmt = function(displayed, _)
			local s = util.shorten_branch_name(displayed, 50)
			return util.unified_format(s)
		end,
	},
	filename = {
		"filename",
	},
	diff = {
		"diff",
		symbols = {
			added = icons.git.added,
			modified = icons.git.modified,
			removed = icons.git.removed,
		},
		source = function()
			local gitsigns = vim.b.gitsigns_status_dict
			if gitsigns then
				return {
					added = gitsigns.added,
					modified = gitsigns.changed,
					removed = gitsigns.removed,
				}
			end
		end,
	},
	python_env = {
		function()
			local utils = require("plugins.specs.lualine.utils")
			if vim.bo.filetype == "python" then
				local venv = os.getenv("CONDA_DEFAULT_ENV")
					or os.getenv("VIRTUAL_ENV")
				if venv then
					local icons = require("nvim-web-devicons")
					local py_icon, _ = icons.get_icon(".py")
					return string.format(
						" " .. py_icon .. " (%s)",
						utils.env_cleanup(venv)
					)
				end
			end
			return ""
		end,
		cond = conditions.hide_in_width,
	},
	diagnostics = {
		"diagnostics",
		symbols = {
			error = icons.diagnostics.BoldError .. " ",
			warn = icons.diagnostics.BoldWarning .. " ",
			info = icons.diagnostics.BoldInformation .. " ",
			hint = icons.diagnostics.BoldHint .. " ",
		},
		cond = conditions.hide_in_width,
	},
	treesitter = {
		function()
			return icons.ui.Tree
		end,
		color = function()
			local buf = vim.api.nvim_get_current_buf()
			local ts = vim.treesitter.highlighter.active[buf]
			return {
				fg = ts and not vim.tbl_isempty(ts) and colors.green
					or colors.red,
			}
		end,
		cond = conditions.hide_in_width,
	},
	lsp = {
		function()
			local buf_clients = vim.lsp.get_active_clients({
				bufnr = vim.api.nvim_get_current_buf(),
			})
			if #buf_clients == 0 then
				return highlights.CatppuccinSurface0(
					icons.ui.LanguageServer
				)
			end

			-- add client
			local lsps = {}
			for _, client in pairs(buf_clients) do
				if client.name ~= "null-ls" and client.name ~= "copilot" then
					table.insert(lsps, client.name)
				end
			end
			if #lsps == 0 then
				return highlights.CatppuccinSurface0(
					icons.ui.LanguageServer
				)
			end
			return highlights.CatppuccinSurface1(
				icons.ui.LanguageServer
			) .. " " .. highlights.CatppuccinBlue(
				util.unique_list_string_format(lsps)
			)
		end,
		cond = function()
			return conditions.hide_in_width() --or conditions.no_clients()
		end,
		padding = { left = 1, right = 1 },
		separator = {
			left = highlights.CatppuccinBase(
				icons.ui.BoldCircleDividerRight
			),
		},
	},
	diagnostics_source = {
		function()
			local diagnostics = util.get_registered_methods("diagnostics")
			if #diagnostics == 0 or not diagnostics then
				return highlights.CatppuccinSurface0(
					icons.ui.DiagnosticsSource
				)
			else
				return highlights.CatppuccinSurface0(
					icons.ui.DiagnosticsSource
				) .. " " .. highlights.CatppuccinBlue(diagnostics)
			end
		end,
		cond = function()
			return conditions.hide_in_width() or conditions.no_clients()
		end,
		padding = { left = 1, right = 1 },
		separator = {
			left = highlights.CatppuccinBase(
				icons.ui.BoldCircleDividerRight
			),
		},
	},
	formatters_source = {
		function()
			local formatters = util.get_registered_methods("formatters")
			if #formatters == 0 or not formatters then
				return highlights.CatppuccinSurface0(
					icons.ui.FormatterSource
				)
			else
				return highlights.CatppuccinSurface1(
					icons.ui.FormatterSource
				) .. " " .. highlights.CatppuccinBlue(formatters)
			end
		end,
		cond = function()
			return conditions.hide_in_width() or conditions.no_clients()
		end,
		padding = { left = 1, right = 1 },
		separator = {
			left = highlights.CatppuccinSurface0(
				icons.ui.BoldCircleDividerRight
			),
		},
	},
	code_action_source = {
		function()
			local code_actions = util.get_registered_methods("code_actions")
			if #code_actions == 0 or not code_actions then
				return highlights.CatppuccinSurface0(
					icons.ui.CodeActionSource
				)
			else
				return highlights.CatppuccinSurface1(
					icons.ui.CodeActionSource
				) .. " " .. highlights.CatppuccinBlue(code_actions)
			end
		end,
		cond = function()
			return conditions.hide_in_width() or conditions.no_clients()
		end,
		padding = { left = 1, right = 1 },
		separator = {
			left = highlights.CatppuccinSurface2(
				icons.ui.BoldCircleDividerRight
			),
		},
	},
	hover_source = {
		function()
			local hover = util.get_registered_methods("hover")
			if #hover == 0 or not hover then
				return highlights.CatppuccinSurface0(
					icons.ui.HoverSource
				)
			else
				return highlights.CatppuccinSurface1(
					icons.ui.HoverSource
				) .. " " .. highlights.CatppuccinTeal(hover)
			end
		end,
		cond = function()
			return conditions.hide_in_width() or conditions.no_clients()
		end,
		padding = { left = 1, right = 2 },
		separator = {
			left = highlights.CatppuccinBase(
				icons.ui.BoldCircleDividerRight
			),
		},
	},
	copilot = {
		function()
			local buf_clients = vim.lsp.get_active_clients({ bufnr = 0 })
			local copilot_active = false

			-- add client
			for _, client in pairs(buf_clients) do
				if client.name == "copilot" then
					copilot_active = true
				end
			end

			local icon = highlights.CatppuccinSurface0(icons.git.Octoface)
			if copilot_active then
				icon = highlights.CatppuccinSurface1(icons.git.Octoface)
			end

			return icon
		end,
		cond = function()
			return conditions.hide_in_width() or conditions.no_clients()
		end,
		padding = { left = 1, right = 1 },
		separator = {
			left = highlights.CatppuccinBase(
				icons.ui.BoldCircleDividerRight
			),
			right = {
				highlights.CatppuccinBase(icons.misc.Stars),
			},
		},
	},
	--noice_recording = {
	--	require("noice").api.statusline.mode.get,
	--	cond = require("noice").api.statusline.mode.has,
	--},
	--noice_message = {
	--	require("noice").api.status.message.get_hl,
	--	cond = require("noice").api.status.message.has,
	--},
	--noice_command = {
	--	require("noice").api.status.command.get,
	--	cond = require("noice").api.status.command.has,
	--},
	--noice_search = {
	--	require("noice").api.status.search.get,
	--	cond = require("noice").api.status.search.has,
	--},
	--noice_ruler = {
	--	require("noice").api.statusline.ruler.get,
	--	cond = require("noice").api.statusline.ruler.has,
	--},
	location = {
		"location",
		fmt = function(string, _)
			return fmt("%s", string)
		end,
		padding = { left = 1, right = 0 },
	},
	progress = {
		"progress",
		fmt = function()
			return "%P/%L"
		end,
	},

	spaces = {
		function()
			local shiftwidth = vim.api.nvim_buf_get_option(0, "shiftwidth")
			return icons.ui.Tab .. " " .. shiftwidth
		end,
		padding = 1,
	},
	encoding = {
		"o:encoding",
		fmt = string.upper,
		color = {},
		cond = conditions.hide_in_width,
	},
	filetype = {
		"filetype",
		cond = nil,
		padding = { left = 2, right = 2 },
		icon_only = true,
	},
}
