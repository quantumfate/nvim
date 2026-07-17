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
		lazy = true,
		dependencies = {
			"nvim-neotest/nvim-nio",
			"theHamsta/nvim-dap-virtual-text",
			"jay-babu/mason-nvim-dap.nvim",
			{
				"igorlfs/nvim-dap-view",
				-- let the plugin lazy load itself
				version = "1.*",
				opts = {
					winbar = {
						controls = {
							enabled = true,
							position = "right",
						},
					},
				},
			},
			{
				"jbyuki/one-small-step-for-vimkind",
				--- Register the nlua adapter for debugging Neovim's own Lua (via osv).
				config = function()
					local dap = require("dap")
					dap.adapters.nlua = function(callback, conf)
						local adapter = {
							type = "server",
							host = conf.host or "127.0.0.1",
							port = conf.port or 8086,
						}
						if conf.start_neovim then
							local dap_run = dap.run
							dap.run = function(c)
								adapter.port = c.port
								adapter.host = c.host
							end
							require("osv").run_this()
							dap.run = dap_run
						end
						callback(adapter)
					end
					dap.configurations.lua = {
						{
							type = "nlua",
							request = "attach",
							name = "Run this file",
							start_neovim = {},
						},
						{
							type = "nlua",
							request = "attach",
							name = "Attach to running Neovim instance (port = 8086)",
							port = 8086,
						},
					}
				end,
			},
		},
		keys = {
			-- Breakpoints
			{
				"<leader>dbt",
				function()
					require("dap").toggle_breakpoint()
				end,
				desc = "Toggle Breakpoint",
			},
			{
				"<leader>dbc",
				function()
					require("dap").set_breakpoint(vim.fn.input("Condition: "))
				end,
				desc = "Conditional Breakpoint",
			},
			{
				"<leader>dbn",
				function()
					require("dap").set_breakpoint(nil, vim.fn.input("Hit Condition: "))
				end,
				desc = "Stop after this breakpoint was hit n times",
			},
			{
				"<leader>dbC",
				function()
					require("dap").clear_breakpoints()
				end,
				desc = "Clear all Breakpoints",
			},
			{
				"<leader>dbed",
				function()
					require("dap").set_exception_breakpoints("default")
				end,
				desc = "Use default settings of debug adapter",
			},
			{
				"<leader>dbea",
				function()
					require("dap").set_exception_breakpoints()
				end,
				desc = "Ask on which kinds of exceptions to stop",
			},
			{
				"<leader>dbeq",
				function()
					require("dap").set_exception_breakpoints()
				end,
				desc = "Exit Debug session on exception",
			},
			-- stepping
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
				"<leader>du",
				function()
					require("dap").up()
				end,
				desc = "Stack up",
			},
			{
				"<leader>dd",
				function()
					require("dap").down()
				end,
				desc = "Stack down",
			},
			-- session
			{
				"<leader>dSp",
				function()
					require("dap").pause()
				end,
				desc = "Pause",
			},

			{
				"<leader>dSr",
				function()
					require("dap").restart()
				end,
				desc = "Restart the current session",
			},
			{
				"<leader>dSt",
				function()
					require("dap").terminate()
				end,
				desc = "Terminate",
			},
			{
				"<leader>dSc",
				function()
					require("dap").continue()
				end,
				desc = "Continue",
			},

			{
				"<leader>dSC",
				function()
					require("dap").run_to_cursor()
				end,
				desc = "Run to Cursor",
			},
			-- Add the word under cursor to watch list
			{
				"<leader>dw",
				function()
					require("dap-view").add_expr()
				end,
				desc = "Watch expression under cursor",
			},
			-- Add visual selection to watch list (works in visual mode)
			{
				"<leader>dw",
				function()
					require("dap-view").add_expr()
				end,
				mode = "v",
				desc = "Watch selection",
			},
			{
				"<leader>dk",
				function()
					require("dap.ui.widgets").hover()
				end,
				desc = "View Value for Expression under the cursor",
			},
		},
		--- Define breakpoint signs, virtual text, edgy hooks, and per-language adapters/configs.
		config = function()
			local dap = require("dap")
			local edgy_util = require("util.plugins.edgy")

			-- icons: global sign glyph table defined during Neovim startup.
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
			dap.listeners.before.attach.edgy_view = function()
				edgy_util.open_view("debug")
			end
			dap.listeners.before.launch.edgy_view = function()
				edgy_util.open_view("debug")
			end
			dap.listeners.before.event_terminated.edgy_view = function()
				edgy_util.close_all()
			end
			dap.listeners.before.event_exited.edgy_view = function()
				edgy_util.close_all()
			end

			-- Lua (local-lua-debugger-vscode, used by neotest-busted)
			dap.adapters["local-lua"] = {
				type = "executable",
				command = "node",
				args = {
					vim.fn.stdpath("data")
						.. "/mason/packages/local-lua-debugger-vscode/extension/extension/debugAdapter.js",
				},
				enrich_config = function(config, on_config)
					if not config["extensionPath"] then
						config.extensionPath = vim.fn.stdpath("data")
							.. "/mason/packages/local-lua-debugger-vscode/extension/"
					end
					config.program = config.program or {}
					if not config.program.lua then
						config.program.lua = vim.fn.exepath("nlua")
					end
					on_config(config)
				end,
			}

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
						return vim.cmd.RustLsp("debuggables")
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
					{
						type = "pwa-node",
						request = "launch",
						name = "Debug Vitest current file",
						runtimeExecutable = "node",
						runtimeArgs = { "./node_modules/vitest/vitest.mjs", "run", "${relativeFile}" },
						rootPath = "${workspaceFolder}",
						cwd = "${workspaceFolder}",
						console = "integratedTerminal",
						internalConsoleOptions = "neverOpen",
						autoAttachChildProcesses = true,
						smartStep = true,
						skipFiles = { "<node_internals>/**", "**/node_modules/**" },
					},
					{
						type = "pwa-node",
						request = "launch",
						name = "Debug Vitest all",
						runtimeExecutable = "node",
						runtimeArgs = { "./node_modules/vitest/vitest.mjs", "run" },
						rootPath = "${workspaceFolder}",
						cwd = "${workspaceFolder}",
						console = "integratedTerminal",
						internalConsoleOptions = "neverOpen",
						autoAttachChildProcesses = true,
						smartStep = true,
						skipFiles = { "<node_internals>/**", "**/node_modules/**" },
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
}
