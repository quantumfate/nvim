-- snacks.picker spec: input keymaps, a cwd/project-root toggle action, and the picker keybindings.

return {
	"folke/snacks.nvim",
	opts = {
		picker = {
			win = {
				input = {
					show_first = false,
					keys = {
						["<a-c>"] = { "toggle_cwd", mode = { "n", "i" } },
						["<a-v>"] = { "edit_vsplit", mode = { "n", "i" } },
						["<a-s>"] = { "edit_split", mode = { "n", "i" } },
						-- Swap Tab/S-Tab with C-j/C-k
						["<Tab>"] = { "list_down", mode = { "n", "i" } },
						["<S-Tab>"] = { "list_up", mode = { "n", "i" } },
						["<C-j>"] = { "select_and_next", mode = { "n", "i" } },
						["<C-k>"] = { "select_and_prev", mode = { "n", "i" } },
					},
				},
			},
			actions = {
				--- Toggles the picker's cwd between the project root and the process cwd.
				---@param p snacks.Picker
				toggle_cwd = function(p)
					local root = require("util.root").get({ buf = p.input.filter.current_buf, normalize = true })
					local cwd = vim.fs.normalize((vim.uv or vim.loop).cwd() or ".")
					p:set_cwd(p:cwd() == root and cwd or root)
					p:find()
				end,
			},
		},
	},
	keys = {
		{
			"<leader><cr>",
			function()
				Snacks.picker.smart({ filter = { cwd = require("util.root")() } })
			end,
			desc = "Find files based on current project root",
		},
		{
			"<leader>fs",
			function()
				Snacks.picker.smart()
			end,
			desc = "Smart Find Files",
		},
		{
			"<leader>/",
			function()
				Snacks.picker.grep()
			end,
			desc = "Grep",
		},
		{
			"<leader>:",
			function()
				Snacks.picker.command_history()
			end,
			desc = "Command History",
		},
		{
			"<leader>fb",
			-- Collects all DAP breakpoints into a picker that jumps to the chosen line.
			function()
				local breakpoints = require("dap.breakpoints").get()
				local items = {}
				for bufnr, buf_bps in pairs(breakpoints) do
					for _, bp in ipairs(buf_bps) do
						local filename = vim.api.nvim_buf_get_name(bufnr)
						items[#items + 1] = {
							text = filename .. ":" .. bp.line,
							file = filename,
							pos = { bp.line, 0 },
						}
					end
				end
				Snacks.picker.pick({
					title = "Breakpoints",
					items = items,
					confirm = function(picker, item)
						picker:close()
						vim.cmd("edit " .. item.file)
						vim.api.nvim_win_set_cursor(0, item.pos)
					end,
				})
			end,
			desc = "List breakpoints",
		},
		-- find
		{
			"<leader>fi",
			function()
				Snacks.picker.icons()
			end,
			desc = "Icons",
		},
		{
			"<leader>fk",
			function()
				Snacks.picker.keymaps()
			end,
			desc = "Keymaps",
		},
		{
			"<leader>fM",
			function()
				Snacks.picker.man()
			end,
			desc = "Man Pages",
		},
		{
			"<leader>fu",
			function()
				Snacks.picker.undo()
			end,
			desc = "Undo History",
		},
		{
			"<leader>fl",
			function()
				Snacks.picker.lazy()
			end,
			desc = "Search for Plugin Spec",
		},
		-- git
		{
			"<leader>fgb",
			function()
				Snacks.picker.git_branches()
			end,
			desc = "Git Branches",
		},
		{
			"<leader>fgl",
			function()
				Snacks.picker.git_log()
			end,
			desc = "Git Log",
		},
		{
			"<leader>fgL",
			function()
				Snacks.picker.git_log_line()
			end,
			desc = "Git Log Line",
		},
		{
			"<leader>fgs",
			function()
				Snacks.picker.git_status()
			end,
			desc = "Git Status",
		},
		{
			"<leader>fgS",
			function()
				Snacks.picker.git_stash()
			end,
			desc = "Git Stash",
		},
		{
			"<leader>fgd",
			function()
				Snacks.picker.git_diff()
			end,
			desc = "Git Diff (Hunks)",
		},
		{
			"<leader>fgf",
			function()
				Snacks.picker.git_log_file()
			end,
			desc = "Git Log File",
		},
		-- gh
		{
			"<leader>fgi",
			function()
				Snacks.picker.gh_issue()
			end,
			desc = "GitHub Issues (open)",
		},
		{
			"<leader>fgI",
			function()
				Snacks.picker.gh_issue({ state = "all" })
			end,
			desc = "GitHub Issues (all)",
		},
		{
			"<leader>fgp",
			function()
				Snacks.picker.gh_pr()
			end,
			desc = "GitHub Pull Requests (open)",
		},
		{
			"<leader>fgP",
			function()
				Snacks.picker.gh_pr({ state = "all" })
			end,
			desc = "GitHub Pull Requests (all)",
		},
		--lsp
		{
			"<leader>flw",
			function()
				Snacks.picker.lsp_workspace_symbols()
			end,
			desc = "LSP workspace symbols",
		},
		{
			"<leader>fls",
			function()
				Snacks.picker.treesitter()
			end,
			desc = "Treesitter symbols",
		},
		{
			"<leader>fld",
			function()
				Snacks.picker.lsp_type_definitions()
			end,
			desc = "LSP type definitions",
		},
		{
			"<leader>fll",
			function()
				Snacks.picker.lsp_symbols()
			end,
			desc = "LSP document symbols",
		},
	},
}
