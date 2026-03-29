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
				{ pattern = "popups", icon = "󰋲", color = "cyan" },
				{ pattern = "harpoon", icon = "󰛢", color = "purple" },
				{ pattern = "interfaces", icon = "", color = "red" },
				{ pattern = "neogen", icon = "", color = "green" },
				{ pattern = "explorer", icon = "", color = "green" },
				{ pattern = "find", icon = "", color = "green" },
				{ pattern = "lsp", icon = "", color = "green" },
				{ pattern = "grep", icon = "", color = "red" },
				{ pattern = "test", icon = "󰂓", color = "red" },
			},
		},
		spec = {
			{
				mode = { "n", "x" },
				-- Core groups - always available
				{ "<leader><tab>", group = "tabs" },
				{ "<leader>h", group = "harpoon" },
				{ "<leader>n", group = "neogen" },
				{ "<leader>f", group = "find" },
				{ "<leader>fl", group = "lsp" },
				{ "<leader>fg", group = "git" },
				{ "<leader>q", group = "quit/session" },
				{ "<leader>s", group = "search/replace" },
				{ "<leader>t", group = "toggle" },
				{ "<leader>i", group = "interfaces" },
				{ "<leader>p", group = "popups" },
				{ "<leader>w", group = "windows", proxy = "<c-w>" },
				{ "<leader>e", group = "explorer" },
				{ "<leader>G", group = "grep" },
				{ "<leader>T", group = "test" },
				{ "<leader>g", group = "git" },
				{ "<leader>gt", group = "toggle" },
				{ "<leader>gF", group = "find" },
				{
					"<leader>c",
					group = "code",
				},
				{
					"<leader>d",
					group = "debug",
				},
				{
					"<leader>r",
					group = "refactor",
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
			"<leader>pl",
			"<cmd>Lazy<cr>",
			desc = "Lazy",
		},
	},
	init = function()
		local wk = require("which-key")
		-- wk.add({
		-- 	{ "<C-f>", "<cmd>silent !tmux neww tms<CR>", desc = "Create a new tms session" },
		-- 	{ "<C-s>", "<cmd>silent !tmux neww tms switch<CR>", desc = "Quick switch sessions" },
		-- })

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
			{ "J", ":m '>+1<CR>gv=gv", desc = "Move selection down", mode = "v" },
			{ "K", ":m '<-2<CR>gv=gv", desc = "Move selection up", mode = "v" },

			{ "J", "mzJ`z", desc = "Join lines (keep cursor)", mode = "n" },
			{ "<C-d>", "<C-d>zz", desc = "Scroll down (centered)", mode = "n" },
			{ "<C-u>", "<C-u>zz", desc = "Scroll up (centered)", mode = "n" },
			{ "n", "nzzzv", desc = "Next search result (centered)", mode = "n" },
			{ "N", "Nzzzv", desc = "Prev search result (centered)", mode = "n" },

			{ "<leader>P", [["_dP]], desc = "Paste without yanking selection", mode = "x" },
			{ "<leader>D", [["_d]], desc = "Delete to black hole register", mode = { "n", "v" } },

			{ "<C-c>", "<Esc>", desc = "Escape insert mode", mode = "i" },

			{ "Q", "<nop>", desc = "Disable ex mode", mode = "n" },
			{ "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>", desc = "Open tmux sessionizer", mode = "n" },

			{ "<C-k>", "<cmd>cnext<CR>zz", desc = "Next quickfix item", mode = "n" },
			{ "<C-j>", "<cmd>cprev<CR>zz", desc = "Prev quickfix item", mode = "n" },
			{ "<leader>k", "<cmd>lnext<CR>zz", desc = "Next location list item", mode = "n" },
			{ "<leader>j", "<cmd>lprev<CR>zz", desc = "Prev location list item", mode = "n" },

			{
				"<leader>ss",
				[[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
				desc = "Search and replace word under cursor",
				mode = "n",
			},
			{
				"<leader>sn",
				function()
					vim.cmd("nohlsearch")
				end,
				desc = "Remove current search pattern",
				mode = "n",
			},
			--{ "<leader>x", "<cmd>!chmod +x %<CR>", desc = "Make file executable", mode = "n" },

			-- {
			-- 	"<leader>ee",
			-- 	"oif err != nil {<CR>}<Esc>Oreturn err<Esc>",
			-- 	desc = "Insert Go error handling",
			-- 	mode = "n",
			-- },
		})
	end,
}
