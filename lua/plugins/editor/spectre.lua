--- Advanced search and replace with live preview and project-wide operations
--- Provides powerful find/replace functionality with capability-aware conditional loading
---@class plugins.editor.spectre
---@field setup fun(): nil

---@class SpectreConfig
---@field open_cmd string Command to open spectre window
---@field live_update boolean Whether to update results in real time
---@field is_insert_mode boolean Whether to start in insert mode
---@field mapping table<string, SpectreMapping> Key mappings for spectre operations

---@class SpectreMapping
---@field map string Key sequence for the mapping
---@field cmd string Command to execute
---@field desc string Description for the mapping

return {
	"nvim-pack/nvim-spectre",
	dependencies = { "nvim-lua/plenary.nvim" },
	cmd = "Spectre",
	---@type SpectreConfig
	opts = {
		open_cmd = "noswapfile vnew",
		live_update = true,
		is_insert_mode = true,
		mapping = {
			["toggle_line"] = {
				map = "dd",
				cmd = "<cmd>lua require('spectre').toggle_line()<CR>",
				desc = "toggle item",
			},
			["enter_file"] = {
				map = "<cr>",
				cmd = "<cmd>lua require('spectre.actions').select_entry()<CR>",
				desc = "open file",
			},
			["send_to_qf"] = {
				map = "<leader>q",
				cmd = "<cmd>lua require('spectre.actions').send_to_qf()<CR>",
				desc = "send all items to quickfix",
			},
			["replace_cmd"] = {
				map = "<leader>c",
				cmd = "<cmd>lua require('spectre.actions').replace_cmd()<CR>",
				desc = "input replace command",
			},
			["show_option_menu"] = {
				map = "<leader>o",
				cmd = "<cmd>lua require('spectre').show_options()<CR>",
				desc = "show options",
			},
			["run_current_replace"] = {
				map = "<leader>rc",
				cmd = "<cmd>lua require('spectre.actions').run_current_replace()<CR>",
				desc = "replace current line",
			},
			["run_replace"] = {
				map = "<leader>R",
				cmd = "<cmd>lua require('spectre.actions').run_replace()<CR>",
				desc = "replace all",
			},
			["change_view_mode"] = {
				map = "<leader>v",
				cmd = "<cmd>lua require('spectre').change_view()<CR>",
				desc = "change result view mode",
			},
			["toggle_live_update"] = {
				map = "tu",
				cmd = "<cmd>lua require('spectre').toggle_live_update()<CR>",
				desc = "toggle live update",
			},
			["toggle_ignore_case"] = {
				map = "ti",
				cmd = "<cmd>lua require('spectre').change_options('ignore-case')<CR>",
				desc = "toggle ignore case",
			},
			["toggle_ignore_hidden"] = {
				map = "th",
				cmd = "<cmd>lua require('spectre').change_options('hidden')<CR>",
				desc = "toggle search hidden",
			},
			["resume_last_search"] = {
				map = "<leader>l",
				cmd = "<cmd>lua require('spectre').resume_last_search()<CR>",
				desc = "resume last search",
			},
		},
	},
	keys = {
		{ "<leader>sr", desc = "Replace in Files (Spectre)" },
		{ "<leader>sw", desc = "Replace Word (Spectre)" },
		{ "<leader>sw", mode = "v", desc = "Replace Selection (Spectre)" },
		{ "<leader>sf", desc = "Replace in Current File (Spectre)" },
	},
	config = function(_, opts)
		require("spectre").setup(opts)

		-- Register conditional keymaps via which-key
		require("which-key").add({
			{
				"<leader>sr",
				function()
					require("spectre").open()
				end,
				desc = "Replace in Files (Spectre)",
			},
			{
				"<leader>sw",
				function()
					require("spectre").open_visual({ select_word = true })
				end,
				desc = "Replace Word (Spectre)",
			},
			{
				"<leader>sw",
				function()
					require("spectre").open_visual()
				end,
				mode = "v",
				desc = "Replace Selection (Spectre)",
			},
			{
				"<leader>sf",
				function()
					require("spectre").open_file_search({ select_word = true })
				end,
				desc = "Replace in Current File (Spectre)",
			},
		})
	end,
}
