--- Window layout management with capability-aware panel toggling
--- Provides context-sensitive sidebar and bottom panel management
---@class plugins.ui.edgy
---@field setup fun(): nil

---@class EdgyViewConfig
---@field ft string Filetype for the panel
---@field title string Display title for the panel
---@field open? string Command to open the panel
---@field filter? fun(buf: integer, win: integer): boolean Filter function for panel visibility
---@field size table Size configuration for the panel

return {
	{
		"folke/edgy.nvim",
		event = "LspAttach",
		init = function()
			vim.opt.laststatus = 3
			vim.opt.splitkeep = "screen"
		end,
		opts = {
			exit_when_last = true,
			bottom = {
				{ title = "Spectre", ft = "spectre_panel", size = { height = 0.4 } },
				{ title = "Neotest Output", ft = "neotest-output-panel", size = { height = 15 } },
				{
					ft = "trouble",
					title = "Diagnostics",
					open = "Trouble diagnostics",
					filter = function(_, win)
						return vim.w[win].trouble and vim.w[win].trouble.mode == "diagnostics"
					end,
					size = { height = 0.3 },
				},
				-- { ft = "qf", title = "QuickFix" },
				{
					ft = "trouble",
					title = "QuickFix List",
					open = "Trouble qflist",
					filter = function(_, win)
						return vim.w[win].trouble and vim.w[win].trouble.mode == "quickfix"
					end,
					size = { height = 0.3 },
				},
				{
					ft = "help",
					size = { height = 20 },
					filter = function(buf)
						return vim.bo[buf].buftype == "help"
					end,
				},
				{
					ft = "snacks_terminal",
					size = { height = 0.3 },
					title = "%{b:snacks_terminal.id}: %{b:term_title}",
					filter = function(_buf, win)
						return vim.w[win].snacks_win
							and vim.w[win].snacks_win.position == "bottom"
							and vim.w[win].snacks_win.relative == "editor"
							and not vim.w[win].trouble_preview
					end,
				},
				{
					ft = "dap-view",
					title = "Debug",
					size = { height = 0.3 },
				},
				{
					ft = "dapui_console",
					title = "Console",
					size = { height = 0.25 },
				},
				{
					ft = "dap-repl",
					title = "REPL",
					size = { height = 0.25 },
				},
			},
			left = {
				-- DAP UI left panels
				{
					ft = "dapui_scopes",
					title = "Scopes",
					size = { width = 60 },
				},
				{
					ft = "dapui_stacks",
					title = "Stacks",
					size = { width = 60 },
				},
				{
					ft = "dapui_breakpoints",
					title = "Breakpoints",
					size = { width = 60 },
				},
				{
					ft = "dapui_watches",
					title = "Watches",
					size = { width = 60 },
				},
				"neo-tree",
			},
			right = {
				{ title = "Neotest Summary", ft = "neotest-summary" },
				{
					ft = "trouble",
					title = "Symbols",
					open = "Trouble symbols focus=false",
					filter = function(_, win)
						return vim.w[win].trouble and vim.w[win].trouble.mode == "symbols"
					end,
					size = { width = 0.3 },
				},
				{
					ft = "trouble",
					title = "LSP",
					open = "Trouble lsp focus=false",
					filter = function(_, win)
						return vim.w[win].trouble and vim.w[win].trouble.mode == "lsp"
					end,
					size = { width = 0.3 },
				},
				{
					ft = "trouble",
					title = "QuickFix List",
					open = "Trouble qflist",
					filter = function(_, win)
						return vim.w[win].trouble and vim.w[win].trouble.mode == "qflist"
					end,
					size = { height = 0.3 },
				},

				{
					ft = "trouble",
					title = "Location List",
					open = "Trouble loclist",
					filter = function(_, win)
						return vim.w[win].trouble and vim.w[win].trouble.mode == "loclist"
					end,
					size = { height = 0.3 },
				},
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
		config = function(_, opts)
			-- neo-tree might not be loaded yet, but we can still read its spec
			local lazy_config = require("lazy.core.config")
			local has_neotree = lazy_config.spec.plugins["neo-tree.nvim"] ~= nil

			if has_neotree then
				local pos = {
					filesystem = "left",
					buffers = "top",
					git_status = "right",
					document_symbols = "bottom",
					diagnostics = "bottom",
				}
				-- Get neo-tree opts from the lazy spec
				local neotree_opts =
					require("lazy.core.plugin").values(lazy_config.spec.plugins["neo-tree.nvim"], "opts", false)
				local sources = (neotree_opts or {}).sources or { "filesystem" }
				local root_fn = require("util.root").get

				for i, v in ipairs(sources) do
					table.insert(opts.left, i, {
						title = "Neo-Tree " .. v:gsub("_", " "):gsub("^%l", string.upper),
						ft = "neo-tree",
						filter = function(buf)
							return vim.b[buf].neo_tree_source == v
						end,
						pinned = true,
						open = function()
							vim.cmd(("Neotree show position=%s %s dir=%s"):format(pos[v] or "bottom", v, root_fn()))
						end,
					})
				end
			end
			require("edgy").setup(opts)
			local edgy_util = require("util.plugins.edgy")

			-- Always available
			require("which-key").add({
				{
					"<leader>ic",
					function()
						edgy_util.close_all()
					end,
					desc = "Edgy: Close All",
				},
				{
					"<leader>is",
					function()
						require("edgy").select()
					end,
					desc = "Edgy Select Window",
				},
			})

			-- LSP-dependent keymaps: register on LspAttach
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("edgy_lsp_keymaps", { clear = true }),
				callback = function(event)
					local buf = event.buf
					local map = function(key, fn, desc)
						vim.keymap.set("n", key, fn, { buffer = buf, desc = desc })
					end

					map("<leader>iD", function()
						edgy_util.toggle_view(edgy_util.views.debug)
					end, "Debug")

					map("<leader>ia", function()
						edgy_util.toggle_view(edgy_util.views.full_trouble)
					end, "Diagnostics, Symbols and LSP")

					map("<leader>id", function()
						edgy_util.toggle_view(edgy_util.views.diagnostics)
					end, "Diagnostics and Symbols")

					map("<leader>ip", function()
						edgy_util.toggle_view(edgy_util.views.project_diagnostics)
					end, "Project Wide Diagnostics")

					map("<leader>il", function()
						edgy_util.toggle_view(edgy_util.views.lsp)
					end, "Symbols and LSP")

					map("<leader>in", function()
						edgy_util.toggle_view(edgy_util.views.neotest)
					end, "Neotest")

					map("<leader>it", function()
						edgy_util.toggle_view(edgy_util.views.list_trouble)
					end, "Symbols, Local- and Quickfix list")

					map("<leader>if", function()
						edgy_util.toggle_view(edgy_util.views.symbols)
					end, "Symbols")
				end,
			})
		end,
	},
}
