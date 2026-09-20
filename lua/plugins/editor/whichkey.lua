--- which-key.nvim: popup key hints, leader group labels, and the config's window/editor keymaps.

--- Reading order for the leader root, so the popup is a map and not a list to scan.
--- Three bands: the work loop, then where things are, then what is switched on.
--- Anything unranked lands after the bands, still alphabetical among itself.
---@type table<string, integer>
local ROOT_ORDER = {
	-- the loop: build it, test it, debug it, look at what it became
	b = 10,
	t = 11,
	d = 12,
	v = 13,
	x = 14,
	r = 15,
	c = 16,
	-- places
	e = 30,
	f = 31,
	G = 32,
	g = 33,
	h = 34,
	m = 35,
	n = 36,
	s = 37,
	i = 38,
	p = 39,
	-- state
	u = 60,
	w = 61,
	B = 62,
	q = 63,
	N = 64,
}

--- Ranks only the leader root; deeper menus keep which-key's own ordering, because a
--- rank meant for `<leader>b` must not reshuffle the `b` inside `<leader>d`.
---@param item { key: string, path: string[] } which-key item (`wk.Item`)
---@return integer
local function root_order(item)
	if #item.path ~= 1 then
		return 0
	end
	-- Unranked keys (stray single mappings like `D` or `/`) sort after every named
	-- group, so the bands above stay contiguous.
	return ROOT_ORDER[item.key] or 100
end

return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts_extend = { "spec" },
	--- Built lazily: the icon rules below read the `icons` global, and a plain table would read it while lazy.nvim
	--- imports this file, pulling the glyph table into startup.
	opts = function()
		return {
			-- Not a preset: the presets are either full width (classic) or a tall side
			-- panel (helix). This is a fixed box, bottom centre, same size every time —
			-- the point is that a group sits where it sat last time.
			preset = false,
			plugins = {
				marks = true,
				registers = true, -- show registers on " and <C-r>
				spelling = {
					enabled = false,
					suggestions = 20,
				},
				-- Built-in help presets; none create keymaps.
				presets = {
					operators = true,
					motions = true,
					text_objects = true,
					windows = true,
					nav = true,
					z = true, -- fold/spelling bindings prefixed with z
					g = true,
				},
			},
			defaults = {},
			-- Hide mappings that carry no description, plus mini.surround's `n`/`l`
			-- (next/last) suffix variants — they triple the `gs` popup for a rare action.
			-- filter = function(mapping)
			-- 	if mapping.desc == "" then
			-- 		return false
			-- 	end
			-- 	local lhs = mapping.lhs or ""
			-- 	if lhs:match("^gs%a[nl]$") then
			-- 		return false
			-- 	end
			-- 	-- `[` / `]` still work, but `-` / `_` are the primary spelling on this
			-- 	-- layout; showing both doubles every motion in the popup.
			-- 	return not lhs:match("^[%[%]]%a")
			-- end,
			win = {
				no_overlap = false,
				width = { min = 40, max = 0.6 },
				height = { min = 4, max = 0.5 },
				col = 0.5,
				row = -2,
				border = "rounded",
				padding = { 0, 1 },
				title = true,
				title_pos = "center",
			},
			layout = {
				-- Narrow columns: descriptions are short, and every column past the
				-- third is a column the eye has to go looking for.
				width = { min = 14, max = 24 },
				spacing = 1,
			},
			-- Groups first and in `ROOT_ORDER`, single keys after. `local` stays in
			-- front so a buffer-local build or test action is the first thing shown.
			sort = { "local", root_order, "order", "alphanum", "mod" },
			-- A group holding one or two keys costs a whole entry and a keystroke;
			-- inline them instead.
			expand = 2,
			icons = {
				-- Icon per label pattern; `icons` is a global from the config's lib.icons module.
				rules = {
					-- Debugging (more specific patterns first)
					{
						pattern = "conditional breakpoint",
						icon = icons.debugging.BreakpointCondition,
						color = "yellow",
					},
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
					{ "<leader>fl", group = "local" },
					{ "<leader>fc", group = "code" },
					{ "<leader>ft", group = "tests" },
					{ "<leader>fg", group = "git" },
					{ "<leader>q", group = "quit/session" },
					{ "<leader>s", group = "search/replace" },
					{ "<leader>st", group = "todo" },
					{ "<leader>t", group = "test" },
					{ "<leader>u", group = "toggle" },
					{ "<leader>B", group = "buffers" },
					{ "<leader>i", group = "interfaces" },
					{ "<leader>x", group = "systems" },
					{ "<leader>p", group = "popups" },
					{ "<leader>w", group = "windows" },
					{ "<leader>e", group = "explorer" },
					{ "<leader>G", group = "grep" },
					{ "<leader>g", group = "git" },
					{ "<leader>gu", group = "toggle" },
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
					{ "<leader>b", group = "build/run" },
					{ "<leader>v", group = "view/inspect" },
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
		}
	end,
	keys = {
		{
			"<leader>iL",
			"<cmd>Lazy<cr>",
			desc = "Lazy",
		},
	},
}
