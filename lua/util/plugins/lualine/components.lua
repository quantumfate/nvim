local conditions = require("util.plugins.lualine.conditions")
local util = require("util.plugins.lualine.util")

local fmt = string.format

local function gitsigns_head()
	local gitsigns = vim.b.gitsigns_status_dict
	if gitsigns then
		return gitsigns.head
	end
end

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
	root = {
		function()
			local root = require("util.fs").get_root()
			local name = vim.fn.fnamemodify(root, ":t")
			return icons.ui.FolderOpen .. " " .. name
		end,
		padding = { left = 2, right = 1 },
		cond = function()
			return not conditions.buffer_is_terminal() and (conditions.hide_in_width() or conditions.no_clients())
		end,
		separator = { right = "" },
	},
	path = {
		require("util.plugins.lualine.util").get_path(),
		padding = { left = 0, right = 2 },
	},
	diff = {
		"diff",
		symbols = {
			added = icons.git.LineAdded .. " ",
			modified = icons.git.LineModified .. " ",
			removed = icons.git.LineRemoved .. " ",
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
		padding = { left = 2, right = 2 },
		separator = { right = "" },
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
		padding = { left = 2, right = 2 },
	},
	diagnostics = {
		"diagnostics",
		symbols = {
			error = icons.diagnostics.Error .. " ",
			warn = icons.diagnostics.Warning .. " ",
			info = icons.diagnostics.Information .. " ",
			hint = icons.diagnostics.Hint .. " ",
		},
		cond = conditions.hide_in_width,
		padding = { left = 2, right = 2 },
	},
	lsp = {
		function()
			local buf_clients = vim.lsp.get_active_clients({
				bufnr = vim.api.nvim_get_current_buf(),
			})
			if #buf_clients == 0 then
				return icons.ui.LanguageServer
			end

			-- add client
			local lsps = {}
			for _, client in pairs(buf_clients) do
				if client.name ~= "null-ls" then
					table.insert(lsps, client.name)
				end
			end
			if #lsps == 0 then
				return icons.ui.LanguageServer
			end
			return util.unique_list_string_format(lsps)
		end,
		cond = function()
			return conditions.hide_in_width() or conditions.no_clients()
		end,
		padding = { left = 3, right = 2 },
	},
	location = {
		"location",
		fmt = function(string, _)
			return fmt("%s", string)
		end,
		padding = { left = 2, right = 2 },
		cond = function()
			return not conditions.buffer_is_terminal()
		end
	},
	progress = {
		"progress",
		fmt = function()
			return "%P/%L"
		end,
		cond = function()
			return not conditions.buffer_is_terminal()
		end
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
		padding = { left = 2, right = 2 },
	},
	filetype = {
		"filetype",
		cond = nil,
		padding = { left = 2, right = 1 },
		icon_only = true,
		separator = { right = "" }, -- override both
	},
}
