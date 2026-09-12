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
		--- Define breakpoint signs, virtual text, dock hooks, and per-language adapters/configs.
		config = function()
			local dap = require("dap")

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
				require("features.workspace").dock().open("debug")
			end
			dap.listeners.before.launch.edgy_view = function()
				require("features.workspace").dock().open("debug")
			end
			dap.listeners.before.event_terminated.edgy_view = function()
				require("features.workspace").dock().close()
			end
			dap.listeners.before.event_exited.edgy_view = function()
				require("features.workspace").dock().close()
			end

			-- Adapters ship as system packages (see lua/toolchain/registry.lua); the two
			-- node-based ones are addressed by path rather than by a `dap` executable.
			local js_debug_server = "/usr/lib/js-debug/dapDebugServer.js"
			-- No distro package exists for this one; the ansible role builds it here.
			local local_lua_debugger = vim.fs.joinpath(vim.fn.stdpath("data"), "dap", "local-lua-debugger-vscode")

			-- Lua (local-lua-debugger-vscode, used by neotest-busted)
			dap.adapters["local-lua"] = {
				type = "executable",
				command = "node",
				args = { local_lua_debugger .. "/extension/debugAdapter.js" },
				enrich_config = function(config, on_config)
					if not config["extensionPath"] then
						config.extensionPath = local_lua_debugger .. "/"
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
						return require("features.lang.python").interpreter()
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
						return require("features.lang.python").interpreter()
					end,
				},
			}

			-- Go (delve's own DAP server; no nvim-dap-go needed)
			dap.adapters.delve = function(cb, config)
				if config.request == "attach" and config.mode == "remote" then
					cb({ type = "server", host = config.host or "127.0.0.1", port = config.port or 38697 })
					return
				end
				cb({
					type = "server",
					port = "${port}",
					executable = { command = vim.fn.exepath("dlv"), args = { "dap", "-l", "127.0.0.1:${port}" } },
				})
			end

			dap.configurations.go = {
				{ type = "delve", name = "Debug package", request = "launch", program = "${fileDirname}" },
				{
					type = "delve",
					name = "Debug tests (package)",
					request = "launch",
					mode = "test",
					program = "${fileDirname}",
				},
				{
					type = "delve",
					name = "Attach to process",
					request = "attach",
					mode = "local",
					processId = function()
						return require("dap.utils").pick_process()
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
			-- gdb speaks DAP itself since 14. It is the one that attaches to QEMU's gdbstub
			-- for kernel work (<leader>xa), and the one that knows the kernel's gdb scripts.
			dap.adapters.gdb = {
				type = "executable",
				command = "gdb",
				args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
			}

			--- The project's binary, from the same picker `<leader>br` uses. C and C++
			--- used to share Rust's table here, which asked rust-analyzer for debuggables.
			---@return thread|string
			local function project_binary()
				local co = coroutine.running()
				local root = require("lib.root").get()
				require("features.lang.binary").select(root, {}, function(path)
					coroutine.resume(co, path)
				end)
				return coroutine.yield()
			end

			local native = {
				{
					name = "Launch (codelldb)",
					type = "codelldb",
					request = "launch",
					program = project_binary,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
				},
				{
					name = "Launch (gdb)",
					type = "gdb",
					request = "launch",
					program = project_binary,
					cwd = "${workspaceFolder}",
				},
				{
					name = "Attach to QEMU gdbstub :1234",
					type = "gdb",
					request = "attach",
					target = "localhost:1234",
					program = function()
						local vmlinux = vim.fs.joinpath(vim.fn.getcwd(), "vmlinux")
						return vim.uv.fs_stat(vmlinux) and vmlinux
							or vim.fn.input("Symbols: ", vim.fn.getcwd() .. "/", "file")
					end,
					cwd = "${workspaceFolder}",
				},
				{
					name = "Attach to rr replay :1234",
					type = "gdb",
					request = "attach",
					target = "localhost:1234",
					program = project_binary,
					cwd = "${workspaceFolder}",
				},
			}
			dap.configurations.c = native
			dap.configurations.cpp = native

			-- Zig (codelldb debugs any ELF binary; sourceLanguages improves stdlib frame rendering)

			--- Build the project, then hand codelldb an executable out of zig-out/bin.
			--- Prompting for a path before building is how you end up debugging a stale
			--- binary, or none at all.
			---@return thread|string
			local function zig_executable()
				local util_root = require("lib.root")
				local buf = vim.api.nvim_get_current_buf()
				-- `zig build` only means anything from the directory holding build.zig.
				local root = util_root.detectors.pattern(buf, "build.zig")[1] or util_root.get({ buf = buf })
				local build = vim.system({ "zig", "build" }, { cwd = root, text = true }):wait()
				if build.code ~= 0 then
					error("zig build failed:\n" .. (build.stderr or ""))
				end

				local candidates = vim.fn.glob(root .. "/zig-out/bin/*", false, true)
				if #candidates == 0 then
					return vim.fn.input("Path to executable: ", root .. "/zig-out/bin/", "file")
				end
				if #candidates == 1 then
					return candidates[1]
				end

				-- More than one artifact: ask, but only among what the build produced.
				local co = coroutine.running()
				vim.ui.select(candidates, {
					prompt = "Zig executable",
					format_item = vim.fs.basename,
				}, function(choice)
					coroutine.resume(co, choice)
				end)
				return coroutine.yield()
			end

			dap.configurations.zig = {
				{
					name = "Launch",
					type = "codelldb",
					request = "launch",
					program = zig_executable,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					sourceLanguages = { "zig" },
				},
			}

			-- JavaScript/TypeScript (js-debug-adapter)
			dap.adapters["pwa-node"] = {
				type = "server",
				host = "localhost",
				port = "${port}",
				executable = {
					command = "node",
					args = {
						js_debug_server,
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
