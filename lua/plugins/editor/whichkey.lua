--- which-key.nvim: popup key hints, leader group labels, and the config's window/editor keymaps.

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
		-- Hide mappings that carry no description, plus mini.surround's `n`/`l`
		-- (next/last) suffix variants — they triple the `gs` popup for a rare action.
		filter = function(mapping)
			if mapping.desc == "" then
				return false
			end
			local lhs = mapping.lhs or ""
			if lhs:match("^gs%a[nl]$") then
				return false
			end
			-- `[` / `]` still work, but `-` / `_` are the primary spelling on this
			-- layout; showing both doubles every motion in the popup.
			return not lhs:match("^[%[%]]%a")
		end,
		-- win = {
		-- 	no_overlap = true,
		-- 	width = 100,
		-- 	height = { min = 4, max = 50 },
		-- 	col = math.floor(total_width * 0.6),
		-- 	row = math.floor(total_height * 0.7),
		-- 	padding = { 2, 3 }, -- [top/bottom, right/left]
		-- 	title = true,
		-- 	title_pos = "center",
		-- 	zindex = 1000,
		-- 	bo = {},
		-- 	wo = {},
		-- },
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
				{ "<leader>m", group = "move/swap" },
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
				{ "<leader>z", group = "zig" },
				-- Navigation groups
				{ "-", group = "next" },
				{ "_", group = "prev" },
				{ "[", group = "prev (legacy)" },
				{ "]", group = "next (legacy)" },
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
}
