return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts_extend = { "spec" },
	opts = {
		preset = "modern",
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
				{ "<leader><tab>", group = "tabs" },
				{ "<leader>b", group = "buffers" },
				{ "<leader>bd", group = "delete" },
				{ "<leader>c", group = "code" },
				{ "<leader>d", group = "debug" },
				{ "<leader>dp", group = "profiler" },
				{ "<leader>f", group = "file/find" },
				{ "<leader>g", group = "git" },
				{ "<leader>gh", group = "hunks" },
				{ "<leader>q", group = "quit/session" },
				{ "<leader>s", group = "search" },
				{ "<leader>u", group = "ui" },
				{ "<leader>ue", group = "edgy" },
				{ "<leader>x", group = "diagnostics/quickfix" },
				{ "[", group = "prev" },
				{ "]", group = "next" },
				{ "g", group = "goto" },
				{ "gs", group = "surround" },
				{ "z", group = "fold" },
				{
					"<leader>b",
					group = "buffer",
					expand = function()
						return require("which-key.extras").expand.buf()
					end,
				},
				{
					"<leader>w",
					group = "windows",
					proxy = "<c-w>",
					expand = function()
						return require("which-key.extras").expand.win()
					end,
				},
				-- better descriptions
				{ "gx", desc = "Open with system app" },
			},
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Keymaps (which-key)",
		},
		{
			"<c-w><space>",
			function()
				require("which-key").show({ keys = "<c-w>", loop = true })
			end,
			desc = "Window Hydra Mode (which-key)",
		},
	},
}
