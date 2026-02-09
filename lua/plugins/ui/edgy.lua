return {
	"folke/edgy.nvim",
	event = "VeryLazy",
	keys = {
		{
			"<leader>ued",
			function()
				require("util.plugins.edgy").toggle_view("diagnostics")
			end,
			desc = "Edgy: Diagnostics View",
		},
		{
			"<leader>uel",
			function()
				require("util.plugins.edgy").toggle_view("lsp")
			end,
			desc = "Edgy: LSP View",
		},
		{
			"<leader>uef",
			function()
				require("util.plugins.edgy").toggle_view("focus")
			end,
			desc = "Edgy: Focus View",
		},
		{
			"<leader>ueb",
			function()
				require("util.plugins.edgy").toggle_view("debug")
			end,
			desc = "Edgy: Debug View",
		},
		{
			"<leader>ue0",
			function()
				require("util.plugins.edgy").close_all()
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
	},

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
}
