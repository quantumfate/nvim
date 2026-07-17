--- which-key.nvim: popup key hints, leader group labels, and the config's window/editor keymaps.

-- Window dimensions sampled at load time to place the which-key popup.
local total_width = vim.api.nvim_win_get_width(0)
local total_height = vim.api.nvim_win_get_height(0)

return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts_extend = { "spec" },
	opts = {
		preset = "helix",
		plugins = {
			marks = false,
			registers = true, -- show registers on " and <C-r>
			spelling = {
				enabled = false,
				suggestions = 20,
			},
			-- Built-in help presets; none create keymaps.
			presets = {
				operators = false,
				motions = false,
				text_objects = false,
				windows = false,
				nav = false,
				z = true, -- fold/spelling bindings prefixed with z
				g = false,
			},
		},
		defaults = {},
		-- Hide mappings that carry no description.
		filter = function(mapping)
			return mapping.desc ~= ""
		end,
		win = {
			no_overlap = true,
			width = 100,
			height = { min = 4, max = 50 },
			col = math.floor(total_width * 0.6),
			row = math.floor(total_height * 0.7),
			padding = { 2, 3 }, -- [top/bottom, right/left]
			title = true,
			title_pos = "center",
			zindex = 1000,
			bo = {},
			wo = {},
		},
		layout = {
			width = { min = 20 },
			spacing = 3,
		},
		icons = {
			-- Icon per label pattern; `icons` is a global from the config's util.icons module.
			rules = {
				-- Debugging (more specific patterns first)
				{ pattern = "conditional breakpoint", icon = icons.debugging.BreakpointCondition, color = "yellow" },
				{ pattern = "breakpoint", icon = icons.debugging.Breakpoint, color = "red" },
				{ pattern = "log point", icon = icons.debugging.BreakpointLog, color = "blue" },
				{ pattern = "continue", icon = icons.debugging.Continue, color = "green" },
				{ pattern = "step into", icon = icons.debugging.StepInto, color = "cyan" },
				{ pattern = "step over", icon = icons.debugging.StepOver, color = "cyan" },
				{ pattern = "step out", icon = icons.debugging.StepOut, color = "cyan" },
				{ pattern = "pause", icon = icons.debugging.Pause, color = "yellow" },
				{ pattern = "terminate", icon = icons.debugging.Terminate, color = "red" },
				{ pattern = "stack up", icon = "", color = "purple" },
				{ pattern = "stack down", icon = "", color = "purple" },
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
				{ pattern = "preview", icon = "󰋲", color = "cyan" },
				{ pattern = "harpoon", icon = "󰛢", color = "purple" },
				{ pattern = "interfaces", icon = "", color = "red" },
				{ pattern = "neogen", icon = "", color = "green" },
				{ pattern = "explorer", icon = "", color = "green" },
				{ pattern = "find", icon = "", color = "green" },
				{ pattern = "lsp", icon = "", color = "green" },
				{ pattern = "grep", icon = "", color = "red" },
				{ pattern = "test", icon = "󰂓", color = "red" },
				{ pattern = "session", icon = "", color = "blue" },
				{ pattern = "breakpoints", icon = "", color = "blue" },
				{ pattern = "exception breakpoints", icon = "", color = "blue" },
			},
		},
		-- Leader-key group labels shown in the which-key popup.
		spec = {
			{
				mode = { "n", "x" },
				-- Core groups
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
				{ "<leader>w", group = "windows" },
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
					"<leader>db",
					group = "breakpoints",
				},
				{
					"<leader>dbe",
					group = "exception breakpoints",
				},

				{
					"<leader>dS",
					group = "session",
				},

				{
					"<leader>r",
					group = "refactor",
				},
				-- Navigation groups
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
		{
			"<leader>iL",
			"<cmd>Lazy<cr>",
			desc = "Lazy",
		},
	},
	-- Register the config's window-management and editing keymaps once which-key loads.
	init = function()
		local wk = require("which-key")

		-- Window navigation, resize, splits, and split swapping.
		wk.add({
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

			-- Swap with neighbor split (file buffers only, skips trouble/edgy/etc.)
			{
				"<leader>w<",
				function()
					require("util.win-swap").swap("h")
				end,
				desc = "Swap with left split",
			},
			{
				"<leader>w>",
				function()
					require("util.win-swap").swap("l")
				end,
				desc = "Swap with right split",
			},
			{
				"<leader>w-",
				function()
					require("util.win-swap").swap("k")
				end,
				desc = "Swap with above split",
			},
			{
				"<leader>w+",
				function()
					require("util.win-swap").swap("j")
				end,
				desc = "Swap with below split",
			},
		})

		-- Editing, movement, search, and register keymaps.
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
		})
	end,
}
