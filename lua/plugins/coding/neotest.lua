return {
	"nvim-neotest/neotest",
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"nvim-neotest/neotest-python",
		"rouge8/neotest-rust",
		"nvim-neotest/neotest-jest",
		"fredrikaverpil/neotest-golang",
	},
	opts = {
		adapters = {
			["neotest-rust"] = {},
			["neotest-python"] = {
				runner = "unittest",
				python = function()
					return require("util.root").get() .. "/.venv/bin/python"
				end,
			},
			["neotest-golang"] = {
				go_test_args = { "-v", "-race", "-timeout", "30s" },
				dap_go_enabled = true, -- enables DAP integration with go-delve
			},
			["neotest-jest"] = {
				jestCommand = "npx jest",
				cwd = function()
					return require("util.root").get()
				end,
			},
		},
	},
	keys = {
		{
			"<leader>Td",
			function()
				require("neotest").run.run({ strategy = "dap" })
			end,
			desc = "Debug nearest test",
		},
		{
			"<leader>Tt",
			function()
				require("neotest").run.run()
			end,
			desc = "Run nearest test",
		},
		{
			"<leader>Tf",
			function()
				require("neotest").run.run(vim.fn.expand("%"))
			end,
			desc = "Run file",
		},
		{
			"<leader>Ts",
			function()
				require("neotest").summary.toggle()
			end,
			desc = "Toggle summary",
		},
		{
			"<leader>To",
			function()
				require("neotest").output.open({ enter = true })
			end,
			desc = "Show output",
		},
	},
}
