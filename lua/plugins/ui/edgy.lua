--- Edgy window-layout (lazy.nvim spec): docks Trouble, DAP, Neo-tree and terminals
--- into edge panels and registers LSP-dependent toggle keymaps.

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

--- Docks a pinned left panel per configured Neo-tree source into opts.left.
---@param opts table Edgy options being assembled
local function add_neotree_panels(opts)
	-- Read neo-tree's spec from lazy even before neo-tree itself loads.
	local lazy_config = require("lazy.core.config")
	if lazy_config.spec.plugins["neo-tree.nvim"] == nil then
		return
	end

	--- Edge each Neo-tree source docks to.
	local source_position = {
		filesystem = "left",
		buffers = "top",
		git_status = "right",
		document_symbols = "bottom",
		diagnostics = "bottom",
	}
	local neotree_opts = require("lazy.core.plugin").values(lazy_config.spec.plugins["neo-tree.nvim"], "opts", false)
	local sources = (neotree_opts or {}).sources or { "filesystem" }
	local project_root = require("util.root").get

	for i, source in ipairs(sources) do
		table.insert(opts.left, i, {
			title = "Neo-Tree " .. source:gsub("_", " "):gsub("^%l", string.upper),
			ft = "neo-tree",
			--- Docks only the window showing this specific source.
			filter = function(buf)
				return vim.b[buf].neo_tree_source == source
			end,
			pinned = true,
			--- Opens this source at its designated edge, rooted at the project.
			open = function()
				vim.cmd(
					("Neotree show position=%s %s dir=%s"):format(
						source_position[source] or "bottom",
						source,
						project_root()
					)
				)
			end,
		})
	end
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
				{ title = "Spectre", ft = "spectre_panel", size = { height = 0.4 } },
				{ title = "Neotest Output", ft = "neotest-output-panel", size = { height = 15 } },
				{
					ft = "trouble",
					title = "Diagnostics",
					open = "Trouble diagnostics",
					filter = trouble_mode_filter("diagnostics"),
					size = { height = 0.3 },
				},
				-- { ft = "qf", title = "QuickFix" },
				{
					ft = "trouble",
					title = "QuickFix List",
					open = "Trouble qflist",
					filter = trouble_mode_filter("quickfix"),
					size = { height = 0.3 },
				},
				{
					ft = "help",
					size = { height = 20 },
					--- Docks only real help buffers, not help-filetype scratch buffers.
					filter = function(buf)
						return vim.bo[buf].buftype == "help"
					end,
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
					filter = trouble_mode_filter("symbols"),
					size = { width = 0.3 },
				},
				{
					ft = "trouble",
					title = "LSP",
					open = "Trouble lsp focus=false",
					filter = trouble_mode_filter("lsp"),
					size = { width = 0.3 },
				},
				{
					ft = "trouble",
					title = "QuickFix List",
					open = "Trouble qflist",
					filter = trouble_mode_filter("qflist"),
					size = { height = 0.3 },
				},

				{
					ft = "trouble",
					title = "Location List",
					open = "Trouble loclist",
					filter = trouble_mode_filter("loclist"),
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
		--- Injects Neo-tree panels, starts edgy, and registers its keymaps.
		config = function(_, opts)
			add_neotree_panels(opts)
			require("edgy").setup(opts)
			local edgy_util = require("util.plugins.edgy")

			-- Panel-management keymaps available regardless of LSP state.
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

			-- View toggles keyed by their trigger; each toggles one edgy view set.
			local view_toggles = {
				{ "<leader>iD", "debug", "Debug" },
				{ "<leader>ia", "full_trouble", "Diagnostics, Symbols and LSP" },
				{ "<leader>id", "diagnostics", "Diagnostics and Symbols" },
				{ "<leader>ip", "project_diagnostics", "Project Wide Diagnostics" },
				{ "<leader>il", "lsp", "Symbols and LSP" },
				{ "<leader>in", "neotest", "Neotest" },
				{ "<leader>it", "list_trouble", "Symbols, Local- and Quickfix list" },
				{ "<leader>if", "symbols", "Symbols" },
			}

			-- View toggles depend on LSP, so bind them per buffer on LspAttach.
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("edgy_lsp_keymaps", { clear = true }),
				callback = function(event)
					local buf = event.buf
					local map = function(key, fn, desc)
						vim.keymap.set("n", key, fn, { buffer = buf, desc = desc })
					end

					for _, toggle in ipairs(view_toggles) do
						local key, view, desc = toggle[1], toggle[2], toggle[3]
						map(key, function()
							edgy_util.toggle_view(edgy_util.views[view])
						end, desc)
					end

					map("<leader>ie", function()
						vim.cmd("wincmd =")
					end, "Equalize Windows")
				end,
			})
		end,
	},
}
