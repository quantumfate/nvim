--- Edgy window-layout (lazy.nvim spec): the edges of the workspace.
---
--- Deliberately short. A panel earns a permanent slot only if it is worth always
--- knowing where it is; everything else opens on demand through `:Trouble` and closes
--- again. The previous version docked nineteen things, five of which were filetypes
--- from nvim-dap-ui — a plugin this config no longer uses.
---
--- The editor area itself (main | aux | outline) is not edgy's business; that is
--- lua/features/workspace/, which also lends `aux` to transient views like navbuddy
--- and the assembly pane so they stop covering the code they describe.

---@class EdgyViewConfig
---@field ft string Filetype for the panel
---@field title string Display title for the panel
---@field open? string Command to open the panel
---@field filter? fun(buf: integer, win: integer): boolean Filter function for panel visibility
---@field size table Size configuration for the panel

--- Panel filter matching a Trouble window in a given mode.
---@param mode string Trouble mode (e.g. "diagnostics", "symbols")
---@return fun(buf: integer, win: integer): boolean
local function trouble_mode_filter(mode)
	return function(_, win)
		-- vim.w[win].trouble is set by trouble.nvim on its own windows.
		return vim.w[win].trouble and vim.w[win].trouble.mode == mode
	end
end

--- Docks a single mutually exclusive sidebar panel into opts.left.
--- Only ONE window occupies the left edge; sources (filesystem, buffers, git_status)
--- replace each other inside it rather than stacking collapsed 1-line slices.
---@param opts table Edgy options being assembled
local function add_neotree_panels(opts)
	-- Read neo-tree's spec from lazy even before neo-tree itself loads.
	local lazy_config = require("lazy.core.config")
	if lazy_config.spec.plugins["neo-tree.nvim"] == nil then
		return
	end

	table.insert(opts.left, 1, {
		title = function()
			local sidebar = require("features.ui.sidebar")
			local active = sidebar.active_source() or "filesystem"
			local label = sidebar.LABELS[active] or "Files"
			local other = sidebar.available_views()
			local other_labels = {}
			for _, v in ipairs(other) do
				table.insert(other_labels, v.label)
			end
			return ("Sidebar: %s  [<Tab> %s]"):format(label, table.concat(other_labels, "/"))
		end,
		ft = "neo-tree",
		pinned = true,
		open = function()
			require("features.ui.sidebar").switch(require("features.ui.sidebar").active_source() or "filesystem")
		end,
	})
end

return {
	{
		"folke/edgy.nvim",
		event = "LspAttach",
		--- Enables a global statusline and stable splits before edgy loads.
		init = function()
			vim.opt.laststatus = 3
			vim.opt.splitkeep = "screen"
		end,
		opts = {
			exit_when_last = true,
			bottom = {
				{
					ft = "trouble",
					title = "Diagnostics",
					open = "Trouble diagnostics",
					filter = trouble_mode_filter("diagnostics"),
					size = { height = 0.3 },
				},
				{
					ft = "trouble",
					title = "QuickFix List",
					open = "Trouble qflist",
					filter = trouble_mode_filter("quickfix"),
					size = { height = 0.3 },
				},
				{
					ft = "snacks_terminal",
					size = { height = 0.3 },
					title = "%{b:snacks_terminal.id}: %{b:term_title}",
					--- Docks only bottom, editor-relative Snacks terminals (not previews).
					filter = function(_buf, win)
						return vim.w[win].snacks_win
							and vim.w[win].snacks_win.position == "bottom"
							and vim.w[win].snacks_win.relative == "editor"
							and not vim.w[win].trouble_preview
					end,
				},
				-- nvim-dap-view is one panel with winbar tabs: scopes, breakpoints,
				-- watches and threads are sections inside it, not separate windows. Only
				-- the debuggee's own terminal is a second buffer.
				{ ft = "dap-view", title = "Debug", size = { height = 0.35 } },
				{ ft = "dap-view-term", title = "Debuggee", size = { height = 0.25 } },
				{ ft = "neotest-output-panel", title = "Test Output", size = { height = 0.3 } },
			},
			left = {
				"neo-tree",
			},
			right = {
				-- The outline. One symbols panel, always in the same place; trouble
				-- follows the active buffer on its own, so it tracks whichever editor
				-- window the cursor is in.
				{
					ft = "trouble",
					title = "Outline",
					open = "Trouble symbols focus=false",
					filter = trouble_mode_filter("symbols"),
					size = { width = 0.22 },
				},
				{ title = "Tests", ft = "neotest-summary", size = { width = 0.22 } },
			},
			animate = {
				enabled = false,
			},
			wo = {
				winhighlight = "Normal:EdgyNormal,WinBar:EdgyWinBar,WinBarNC:EdgyWinBarInactive",
				winbar = true,
				signcolumn = "no",
				number = false,
				relativenumber = false,
			},
		},
		--- Injects Neo-tree panels, starts edgy, and registers its keymaps.
		config = function(_, opts)
			add_neotree_panels(opts)
			require("edgy").setup(opts)

			-- One key per dock view, each a plain toggle. The previous version had a
			-- push/pop stack of eight "view presets" behind `<leader>i*`, which meant
			-- learning which letter opened which *combination* — and none of them were
			-- mutually exclusive, so panels stacked at the bottom anyway.
			--
			-- The dock holds one view at a time (lua/features/workspace/dock.lua): the
			-- same key puts it away, a different key swaps to it, and closing tears the
			-- window down.
			local dock = require("features.workspace").dock()
			require("which-key").add({
				{
					"<leader>iq",
					function()
						dock.toggle("diagnostics")
					end,
					desc = "Diagnostics",
				},
				{
					"<leader>il",
					function()
						dock.toggle("loclist")
					end,
					desc = "Loclist",
				},
				{
					"<leader>is",
					function()
						dock.toggle("symbols")
					end,
					desc = "Symbols",
				},
				{
					"<leader>iQ",
					function()
						dock.toggle("project")
					end,
					desc = "Project diagnostics",
				},
				{
					"<leader>it",
					function()
						dock.toggle("todo")
					end,
					desc = "Todos",
				},
				{
					"<leader>iT",
					function()
						dock.toggle("terminal")
					end,
					desc = "Terminal",
				},
				{
					"<leader>iD",
					function()
						dock.toggle("debug")
					end,
					desc = "Debug",
				},
				{
					"<leader>in",
					function()
						dock.toggle("tests")
					end,
					desc = "Tests",
				},
				{
					"<leader>ic",
					function()
						dock.close()
					end,
					desc = "Close the dock",
				},
				{
					"<leader>ie",
					function()
						require("features.workspace").equalize()
					end,
					desc = "Equalize Windows",
				},
				{
					"<leader>iS",
					function()
						require("edgy").select()
					end,
					desc = "Edgy Select Window",
				},
			})
		end,
	},
}
