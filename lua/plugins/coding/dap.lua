--- Debug Adapter Protocol (DAP) configuration for Neovim debugging
--- Provides comprehensive debugging support for multiple languages with conditional keymaps
--- @class plugins.coding.dap
--- @field setup fun(): nil

--- DAP adapter configuration for different debug protocols
--- @class DapAdapter
--- @field type string Adapter connection type ("server", "executable", etc.)
--- @field port? string Port specification for server adapters
--- @field host? string Host address for server connections
--- @field executable? table Command and arguments for executable adapters
--- @field options? table Additional adapter-specific options

--- DAP configuration for language-specific debugging
--- @class DapConfiguration
--- @field type string Debug adapter type to use
--- @field request string Debug request type ("launch", "attach")
--- @field name string Human-readable configuration name
--- @field program? string|fun(): string Path to program or function returning path
--- @field cwd? string Working directory for debug session
--- @field args? string[]|fun(): string[] Program arguments
--- @field pythonPath? fun(): string Python interpreter path resolver
--- @field stopOnEntry? boolean Whether to stop at program entry point
--- @field processId? fun(): number Process ID picker for attach requests

return {
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"theHamsta/nvim-dap-virtual-text",
			"jay-babu/mason-nvim-dap.nvim",
		},
		keys = {
			{
				"<leader>db",
				function()
					require("dap").toggle_breakpoint()
				end,
				desc = "Toggle Breakpoint",
			},
			{
				"<leader>dB",
				function()
					require("dap").set_breakpoint(vim.fn.input("Condition: "))
				end,
				desc = "Conditional Breakpoint",
			},
			{
				"<leader>dc",
				function()
					require("dap").continue()
				end,
				desc = "Continue",
			},
			{
				"<leader>dC",
				function()
					require("dap").run_to_cursor()
				end,
				desc = "Run to Cursor",
			},
			{
				"<leader>di",
				function()
					require("dap").step_into()
				end,
				desc = "Step Into",
			},
			{
				"<leader>do",
				function()
					require("dap").step_over()
				end,
				desc = "Step Over",
			},
			{
				"<leader>dO",
				function()
					require("dap").step_out()
				end,
				desc = "Step Out",
			},
			{
				"<leader>dp",
				function()
					require("dap").pause()
				end,
				desc = "Pause",
			},
			{
				"<leader>dr",
				function()
					require("dap").repl.toggle()
				end,
				desc = "Toggle REPL",
			},
			{
				"<leader>ds",
				function()
					require("dap").session()
				end,
				desc = "Session",
			},
			{
				"<leader>dt",
				function()
					require("dap").terminate()
				end,
				desc = "Terminate",
			},
			{
				"<leader>du",
				function()
					require("util.plugins.edgy").toggle_view("debug")
				end,
				desc = "Toggle Debug View",
			},
			{
				"<leader>de",
				function()
					require("dapui").eval()
				end,
				desc = "Eval",
				mode = { "n", "v" },
			},
			{
				"<leader>dw",
				function()
					require("dap.ui.widgets").hover()
				end,
				desc = "Widgets",
			},
		},
		config = function()
			local dap = require("dap")
			local edgy_util = require("util.plugins.edgy")

			vim.fn.sign_define("DapBreakpoint", { text = icons.debugging.Breakpoint, texthl = "DiagnosticError" })
			vim.fn.sign_define(
				"DapBreakpointCondition",
				{ text = icons.debugging.BreakpointCondition, texthl = "DiagnosticWarn" }
			)
			vim.fn.sign_define(
				"DapBreakpointRejected",
				{ text = icons.debugging.BreakpointUnsupported, texthl = "DiagnosticError" }
			)
			vim.fn.sign_define("DapLogPoint", { text = icons.debugging.BreakpointLog, texthl = "DiagnosticInfo" })
			vim.fn.sign_define(
				"DapStopped",
				{ text = icons.debugging.Stopped, texthl = "DiagnosticOk", linehl = "DapStoppedLine" }
			)

			-- Virtual text
			require("nvim-dap-virtual-text").setup({
				enabled = true,
				enabled_commands = false,
			})

			-- Unfortunately, the way these events are emitted it's the state history of edgy util is completely flushed
			-- I prefer a working util over compensating for dap
			dap.listeners.before.attach.dapui_config = function()
				edgy_util.open_view("debug")
			end
			dap.listeners.before.launch.dapui_config = function()
				edgy_util.open_view("debug")
			end
			dap.listeners.before.event_terminated.dapui_config = function()
				edgy_util.close_all()
			end
			dap.listeners.before.event_exited.dapui_config = function()
				edgy_util.close_all()
			end

			-- Python (debugpy)
			dap.adapters.python = function(cb, config)
				if config.request == "attach" then
					local port = (config.connect or config).port
					local host = (config.connect or config).host or "127.0.0.1"
					cb({
						type = "server",
						port = assert(port, "`connect.port` is required for attach"),
						host = host,
						options = { source_filetype = "python" },
					})
				else
					cb({
						type = "executable",
						command = vim.fn.exepath("debugpy-adapter"),
						options = { source_filetype = "python" },
					})
				end
			end

			dap.configurations.python = {
				{
					type = "python",
					request = "launch",
					name = "Launch file",
					program = "${file}",
					pythonPath = function()
						local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
						if venv then
							return venv .. "/bin/python"
						end
						return vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
					end,
				},
				{
					type = "python",
					request = "launch",
					name = "Launch with arguments",
					program = "${file}",
					args = function()
						local args_string = vim.fn.input("Arguments: ")
						return vim.split(args_string, " +")
					end,
					pythonPath = function()
						local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
						if venv then
							return venv .. "/bin/python"
						end
						return vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
					end,
				},
			}

			-- Rust/C/C++ (codelldb)
			dap.adapters.codelldb = {
				type = "server",
				port = "${port}",
				executable = {
					command = vim.fn.exepath("codelldb"),
					args = { "--port", "${port}" },
				},
			}

			dap.configurations.rust = {
				{
					name = "Launch",
					type = "codelldb",
					request = "launch",
					program = function()
						return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
					end,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
				},
			}
			dap.configurations.c = dap.configurations.rust
			dap.configurations.cpp = dap.configurations.rust

			-- JavaScript/TypeScript (js-debug-adapter)
			dap.adapters["pwa-node"] = {
				type = "server",
				host = "localhost",
				port = "${port}",
				executable = {
					command = "node",
					args = {
						vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
						"${port}",
					},
				},
			}

			for _, lang in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
				dap.configurations[lang] = {
					{
						type = "pwa-node",
						request = "launch",
						name = "Launch file",
						program = "${file}",
						cwd = "${workspaceFolder}",
					},
					{
						type = "pwa-node",
						request = "attach",
						name = "Attach",
						processId = require("dap.utils").pick_process,
						cwd = "${workspaceFolder}",
					},
				}
			end

			-- Go (delve)
			dap.adapters.delve = {
				type = "server",
				port = "${port}",
				executable = {
					command = "dlv",
					args = { "dap", "-l", "127.0.0.1:${port}" },
				},
			}

			dap.configurations.go = {
				{
					type = "delve",
					name = "Debug",
					request = "launch",
					program = "${file}",
				},
				{
					type = "delve",
					name = "Debug Package",
					request = "launch",
					program = "${fileDirname}",
				},
			}
		end,
	},
	{
		"igorlfs/nvim-dap-view",
		-- let the plugin lazy load itself
		lazy = false,
		version = "1.*",
		opts = {},
	},
}
