return {
	"folke/snacks.nvim",
	opts = {
		picker = {
			win = {
				input = {
					show_first = false,
					keys = {
						["<a-c>"] = {
							"toggle_cwd",
							mode = { "n", "i" },
						},
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
				toggle_cwd = function(p)
					local root = require("util.root").get({ buf = p.input.filter.current_buf, normalize = true })
					local cwd = vim.fs.normalize((vim.uv or vim.loop).cwd() or ".")
					local current = p:cwd()
					p:set_cwd(current == root and cwd or root)
					p:find()
				end,
			},
		},
	},
	keys = {
		{
			"<leader><cr>",
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
		-- LSP
		-- {
		-- 	"gd",
		-- 	function()
		-- 		Snacks.picker.lsp_definitions()
		-- 	end,
		-- 	desc = "Goto Definition",
		-- },
		-- {
		-- 	"gD",
		-- 	function()
		-- 		Snacks.picker.lsp_declarations()
		-- 	end,
		-- 	desc = "Goto Declaration",
		-- },
		-- {
		-- 	"gr",
		-- 	function()
		-- 		Snacks.picker.lsp_references()
		-- 	end,
		-- 	nowait = true,
		-- 	desc = "References",
		-- },
		-- {
		-- 	"gI",
		-- 	function()
		-- 		Snacks.picker.lsp_implementations()
		-- 	end,
		-- 	desc = "Goto Implementation",
		-- },
		-- {
		-- 	"gy",
		-- 	function()
		-- 		Snacks.picker.lsp_type_definitions()
		-- 	end,
		-- 	desc = "Goto T[y]pe Definition",
		-- },
		-- {
		-- 	"gai",
		-- 	function()
		-- 		Snacks.picker.lsp_incoming_calls()
		-- 	end,
		-- 	desc = "C[a]lls Incoming",
		-- },
		-- {
		-- 	"gao",
		-- 	function()
		-- 		Snacks.picker.lsp_outgoing_calls()
		-- 	end,
		-- 	desc = "C[a]lls Outgoing",
		-- },
		-- {
		-- 	"<leader>ss",
		-- 	function()
		-- 		Snacks.picker.lsp_symbols()
		-- 	end,
		-- 	desc = "LSP Symbols",
		-- },
		-- {
		-- 	"<leader>sS",
		-- 	function()
		-- 		Snacks.picker.lsp_workspace_symbols()
		-- 	end,
		-- 	desc = "LSP Workspace Symbols",
		-- },
	},
}
