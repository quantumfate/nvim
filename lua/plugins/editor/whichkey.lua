local total_width = vim.api.nvim_win_get_width(0)

-- Height in character cells
local total_height = vim.api.nvim_win_get_height(0)
return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts_extend = { "spec" },
	opts = {
		preset = "helix",
		plugins = {
			marks = false, -- shows a list of your marks on ' and `
			registers = true, -- shows your registers on " in NORMAL or <C-r> in INSERT mode
			-- the presets plugin, adds help for a bunch of default keybindings in Neovim
			-- No actual key bindings are created
			spelling = {
				enabled = false, -- enabling this will show WhichKey when pressing z= to select spelling suggestions
				suggestions = 20, -- how many suggestions should be shown in the list?
			},
			presets = {
				operators = true, -- adds help for operators like d, y, ...
				motions = true, -- adds help for motions
				text_objects = true, -- help for text objects triggered after entering an operator
				windows = false, -- default bindings on <c-w>
				nav = false, -- misc bindings to work with windows
				z = true, -- bindings for folds, spelling and others prefixed with z
				g = false, -- bindings for prefixed with g
			},
		},
		defaults = {},
		filter = function(mapping)
			return mapping.desc ~= ""
		end,
		win = {
			no_overlap = true,
			width = 100,
			height = { min = 4, max = 50 },
			col = math.floor(total_width * 0.6), -- Center horizontally
			row = math.floor(total_height * 0.7), -- 25% from top
			-- border = "none",
			padding = { 2, 3 }, -- extra window padding [top/bottom, right/left]
			title = true,
			title_pos = "center",
			zindex = 1000,
			-- Additional vim.wo and vim.bo options
			bo = {},
			wo = {
				-- winblend = 10, -- value between 0-100 0 for fully opaque and 100 for fully transparent
			},
		},
		layout = {
			width = { min = 20 }, -- min and max width of the columns
			spacing = 3, -- spacing between columns
		},
		icons = {
			rules = {
				-- Debugging icons (more specific patterns first)
				{ pattern = "conditional breakpoint", icon = icons.debugging.BreakpointCondition, color = "yellow" },
				{ pattern = "breakpoint", icon = icons.debugging.Breakpoint, color = "red" },
				{ pattern = "log point", icon = icons.debugging.BreakpointLog, color = "blue" },
				{ pattern = "continue", icon = icons.debugging.Continue, color = "green" },
				{ pattern = "step into", icon = icons.debugging.StepInto, color = "cyan" },
				{ pattern = "step over", icon = icons.debugging.StepOver, color = "cyan" },
				{ pattern = "step out", icon = icons.debugging.StepOut, color = "cyan" },
				{ pattern = "pause", icon = icons.debugging.Pause, color = "yellow" },
				{ pattern = "terminate", icon = icons.debugging.Terminate, color = "red" },
				{ pattern = "disconnect", icon = icons.debugging.Disconnect, color = "red" },
				{ pattern = "restart", icon = icons.debugging.Restart, color = "orange" },
				{ pattern = "run to cursor", icon = icons.debugging.Continue, color = "green" },
				{ pattern = "run last", icon = icons.debugging.Continue, color = "green" },
				{ pattern = "repl", icon = icons.ui.DebugConsole, color = "purple" },
				{ pattern = "eval", icon = icons.ui.Code, color = "blue" },
				{ pattern = "session", icon = icons.ui.Stacks, color = "purple" },
				{ pattern = "widget", icon = icons.ui.Watches, color = "cyan" },
				{ pattern = "debug view", icon = icons.ui.Scopes, color = "purple" },
				{ pattern = "up.*frame", icon = icons.ui.BoldArrowUp, color = "cyan" },
				{ pattern = "down.*frame", icon = icons.ui.BoldArrowDown, color = "cyan" },
				{ pattern = "go to line", icon = icons.debugging.StepOver, color = "cyan" },
			},
		},
		spec = {
			{
				mode = { "n", "x" },
				-- Core groups - always available
				{ "<leader><tab>", group = "tabs" },
				{ "<leader>b", group = "buffer" },
				{ "<leader>bd", group = "delete" },
				{ "<leader>f", group = "file/find" },
				{ "<leader>q", group = "quit/session" },
				{ "<leader>s", group = "search" },
				{ "<leader>t", group = "toggle" },
				{ "<leader>u", group = "ui" },
				{ "<leader>w", group = "windows", proxy = "<c-w>" },
				{ "<leader>ue", group = "edgy" },
				{ "<leader>a", group = "avante" },
				{ "<leader>ap", group = "providers" },
				{
					"<leader>ad",
					group = "diff",
				},
				{
					"<leader>af",
					group = "file",
				},
				{
					"<leader>at",
					group = "templates",
				},
				{
					"<leader>c",
					group = "code",
				},
				{
					"<leader>d",
					group = "debug",
				},
				{
					"<leader>dp",
					group = "profiler",
				},
				{
					"<leader>g",
					group = "git",
				},
				{
					"<leader>gh",
					group = "hunks",
				},
				{
					"<leader>r",
					group = "refactor",
				},
				{
					"<leader>x",
					group = "diagnostics/quickfix",
				},
				-- Navigation groups - context dependent
				{
					"[",
					group = "prev",
				},
				{
					"]",
					group = "next",
				},
				{
					"g",
					group = "goto",
				},
				{
					"gs",
					group = "surround",
				},
				{
					"z",
					group = "fold",
				},

				-- Better descriptions
				{ "gx", desc = "Open with system app" },
			},
		},
	},
	keys = {
		-- {
		-- 	"<leader>?",
		-- 	function()
		-- 		require("which-key").show({ global = false })
		-- 	end,
		-- 	desc = "Buffer Keymaps (which-key)",
		-- },
		{
			"<leader>ul",
			"<cmd>Lazy<cr>",
			desc = "Lazy",
		},
	},
	init = function()
		local wk = require("which-key")

		wk.add({
			-- Existing navigation...
			{ "<leader>wh", "<cmd>wincmd h<cr>", desc = "Left" },
			{ "<leader>wj", "<cmd>wincmd j<cr>", desc = "Down" },
			{ "<leader>wk", "<cmd>wincmd k<cr>", desc = "Up" },
			{ "<leader>wl", "<cmd>wincmd l<cr>", desc = "Right" },
			{ "<leader>wx", "<cmd>close<cr>", desc = "Close" },

			-- Resize mappings (2 lines/columns at a time)
			{ "<leader>wH", "<cmd>vertical resize +2<cr>", desc = "Height +2" },
			{ "<leader>wJ", "<cmd>resize +2<cr>", desc = "Width +2" },
			{ "<leader>wK", "<cmd>resize -2<cr>", desc = "Width -2" },
			{ "<leader>wL", "<cmd>vertical resize -2<cr>", desc = "Height -2" },

			-- Splits and balance
			{ "<leader>wv", "<cmd>vsplit<cr>", desc = "Vertical split" },
			{ "<leader>ws", "<cmd>split<cr>", desc = "Horizontal split" },
			{ "<leader>w=", "<cmd>wincmd =<cr>", desc = "Balance" },
		})

		wk.add({
			-- Navigation (your original proxies)
			{ "<C-h>", "<cmd>wincmd h<cr>", desc = "Left", mode = "n" },
			{ "<C-j>", "<cmd>wincmd j<cr>", desc = "Down", mode = "n" },
			{ "<C-k>", "<cmd>wincmd k<cr>", desc = "Up", mode = "n" },
			{ "<C-l>", "<cmd>wincmd l<cr>", desc = "Right", mode = "n" },
			{ "<a-x>", "<cmd>close<cr>", desc = "Close", mode = "n" },

			-- Resize mappings (2 lines/columns at a time)
			{ "<A-h>", "<cmd>vertical resize +2<cr>", desc = "Height +", mode = "n" },
			{ "<A-j>", "<cmd>resize +2<cr>", desc = "Width +", mode = "n" },
			{ "<A-k>", "<cmd>resize -2<cr>", desc = "Height -", mode = "n" },
			{ "<A-l>", "<cmd>vertical resize -2<cr>", desc = "Width -", mode = "n" },
			-- Working with splits
			{ "<a-v>", "<cmd>vsplit<cr>", desc = "Vertical split", mode = "n" },
			{ "<a-s>", "<cmd>split<cr>", desc = "Horizontol split", mode = "n" },
			{ "<a-cr>", "<cmd>wincmd =<cr>", desc = "Balance windows", mode = "n" }, -- Ctrl+Enter
		})
	end,
}
