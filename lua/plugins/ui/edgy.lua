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
	"folke/edgy.nvim",
	event = "LspAttach",
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
				filter = function(_, win)
					return vim.w[win].trouble and vim.w[win].trouble.mode == "diagnostics"
				end,
				size = { height = 0.3 },
			},
			{ ft = "qf", title = "QuickFix" },
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
			-- DAP UI bottom panels
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
		},
		right = {
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
		require("edgy").setup(opts)
		local edgy_util = require("util.plugins.edgy")

		-- Always available
		require("which-key").add({
			{ "<leader>ue", group = "edgy" },
			{
				"<leader>ue0",
				function()
					edgy_util.close_all()
				end,
				desc = "Edgy: Close All",
			},
			{
				"<leader>ues",
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

				map("<leader>ued", function()
					edgy_util.toggle_view("diagnostics")
				end, "Edgy: Diagnostics View")

				map("<leader>uel", function()
					edgy_util.toggle_view("lsp")
				end, "Edgy: LSP View")

				map("<leader>uef", function()
					edgy_util.toggle_view("focus")
				end, "Edgy: Focus View")
			end,
		})

		-- Debug keymaps: register for supported filetypes
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("edgy_debug_keymaps", { clear = true }),
			pattern = { "python", "go", "rust", "javascript", "typescript", "c", "cpp", "java" },
			callback = function(event)
				vim.keymap.set("n", "<leader>ueb", function()
					edgy_util.toggle_view("debug")
				end, { buffer = event.buf, desc = "Edgy: Debug View" })
			end,
		})
	end,
}
