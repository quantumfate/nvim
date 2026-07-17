--- Lualine (lazy.nvim spec): statusline and winbar assembled from the shared
--- component and color helpers in util.plugins.lualine.

---@class LualineConfig
---@field options table Statusline appearance and behavior configuration
---@field sections table Component layout for active statusline sections
---@field inactive_sections table Component layout for inactive windows
---@field extensions string[] Plugin extensions to load

return {
	"nvim-lualine/lualine.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"catppuccin/nvim",
	},
	event = "User FileOpened",
	--- Builds the config from the shared color theme and component helpers.
	opts = function()
		local color = require("util.plugins.lualine.color")
		local lualine_components = require("util.plugins.lualine.components")
		-- `icons` and `Snacks` below are globals set up elsewhere in the config.
		return {
			options = {
				always_divide_middle = true,
				always_show_tabline = true,
				component_separators = {
					left = icons.ui.HollowDividerLeft,
					right = icons.ui.HollowDividerRight,
				},
				section_separators = {
					left = icons.ui.BoldDividerLeft,
					right = icons.ui.BoldDividerRight,
				},
				theme = color,
				disabled_filetypes = {
					statusline = {
						"alpha",
						"dashboard",
						"NvimTree",
						"Outline",
						"snacks_dashboard",
						"Navbuddy",
						"snacks_picker_input",
					},
					winbar = {
						"alpha",
						"dashboard",
						"NvimTree",
						"Outline",
						"snacks_dashboard",
					},
				},
				refresh = {
					statusline = 1000,
					tabline = 1000,
					winbar = 1000,
					refresh_time = 16, -- ~60fps
					events = {
						"WinEnter",
						"BufEnter",
						"BufWritePost",
						"SessionLoadPost",
						"FileChangedShellPost",
						"VimResized",
						"Filetype",
						"CursorMoved",
						"CursorMovedI",
						"ModeChanged",
					},
				},
				globalstatus = true,
			},
			sections = {
				lualine_a = {
					lualine_components.mode,
					lualine_components.branch,
				},
				lualine_b = {
					lualine_components.root,
					lualine_components.view,
					lualine_components.remote_nvim,
				},
				lualine_c = {
					lualine_components.harpoon,
				},
				lualine_x = {
					Snacks.profiler.status(),
					lualine_components.command_status,
					lualine_components.mode_status,
					lualine_components.debug_status,
					lualine_components.updates_available,

					lualine_components.diff,
					lualine_components.diagnostics,
					lualine_components.python_env,

					lualine_components.searchcount,
					lualine_components.wordcount,
				},
				lualine_y = {

					lualine_components.location,
					lualine_components.progress,
				},
				lualine_z = {
					lualine_components.lsp,
				},
			},
			inactive_sections = {
				lualine_a = {},
				lualine_b = {
					lualine_components.path,
				},
				lualine_c = {},
				lualine_x = {
					lualine_components.filetype,
				},
				lualine_y = {

					lualine_components.location,
				},
				lualine_z = {},
			},
			-- tabline = {
			-- 	lualine_a = {
			-- lualine_components.remote_nvim,
			-- 	},
			-- 	lualine_b = {},
			-- 	lualine_c = {},
			-- 	lualine_x = {},
			-- 	lualine_y = {},
			-- 	lualine_z = {
			-- 		-- TODO: edgy view
			-- 	},
			-- },
			winbar = {
				lualine_b = {
					lualine_components.filetype,
				},
				lualine_c = {
					lualine_components.path,
					lualine_components.navic,
				},
			},
			inactive_winbar = {
				lualine_b = {
					lualine_components.filetype,
				},
				lualine_c = {
					lualine_components.path,
				},
			},

			extensions = {
				"aerial",
				"assistant",
				"avante",
				"chadtree",
				"ctrlspace",
				"fern",
				"fugitive",
				"fzf",
				"lazy",
				"man",
				"mason",
				"mundo",
				"neo-tree",
				"nerdtree",
				"nvim-dap-ui",
				"nvim-tree",
				"oil",
				"overseer",
				"quickfix",
				"symbols-outline",
				"toggleterm",
				"trouble",
			},
		}
	end,
}
