--- neotest spec: multi-language test runner wired to trouble and the edgy layout,
--- with ANSI escape codes stripped from every adapter's output.
return {
	"nvim-neotest/neotest",
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"nvim-neotest/neotest-python",
		"rouge8/neotest-rust",
		"nvim-neotest/neotest-jest",
		"marilari88/neotest-vitest",
		"fredrikaverpil/neotest-golang",
		"MisanthropicBit/neotest-busted",
		"folke/trouble.nvim",
	},
	opts = {
		adapters = {
			["neotest-python"] = {
				python = function()
					return require("util.root").get() .. "/.venv/bin/python"
				end,
				args = { "-v" },
				env = {
					NO_COLOR = "1",
					TERM = "dumb",
					PYTHONPATH = "src",
				},
			},
			["neotest-golang"] = {
				go_test_args = { "-v", "-race", "-count=1", "-timeout=60s" },
				dap_go_enabled = true,
				env = {
					NO_COLOR = "1",
					TERM = "dumb",
				},
			},
			["rustaceanvim.neotest"] = {},
			["neotest-busted"] = {
				minimal_init = "tests/minimal_init.lua",
				local_luarocks_only = false, -- Default local_luarocks_only = true blocks ~/.luarocks lookup (init.lua:96-98). User has no project-local lua_modules/, so nil returned.
			},
			["neotest-jest"] = {
				jestCommand = "npx jest --no-color",
				cwd = function()
					return require("util.root").get()
				end,
			},
			["neotest-vitest"] = {
				-- Vitest auto-detects vite.config.ts upward from each test file,
				-- so cwd defaults work in the pnpm monorepo (web/ has the config).
				filter_dir = function(name)
					return name ~= "node_modules" and name ~= "build" and name ~= ".svelte-kit"
				end,
			},
		},
		-- Example for loading neotest-golang with a custom config
		-- adapters = {
		--   ["neotest-golang"] = {
		--     go_test_args = { "-v", "-race", "-count=1", "-timeout=60s" },
		--     dap_go_enabled = true,
		--   },
		-- },

		status = { virtual_text = true },
		output = { open_on_run = true },
		quickfix = {
			open = function()
				require("trouble").open({ mode = "quickfix", focus = false })
			end,
		},
	},
	--- Strip ANSI from every adapter, wire the trouble consumer, then set up neotest.
	config = function(_, opts)
		-- Wrap an adapter's `results` so ANSI escape codes are stripped from messages and output files.
		local function wrap_adapter(adapter)
			local original_results = adapter.results
			adapter.results = function(spec, result, tree)
				local results = original_results(spec, result, tree)
				for pos_id, r in pairs(results or {}) do
					if r.short then
						r.short = r.short:gsub("\27%[[%d;]*m", "")
					end
					if r.errors then
						for _, err in ipairs(r.errors) do
							if err.message then
								err.message = err.message:gsub("\27%[[%d;]*m", "")
							end
						end
					end
					if r.output and type(r.output) == "string" then
						local f = io.open(r.output, "r")
						if f then
							local content = f:read("*a")
							f:close()
							local cleaned = content:gsub("\27%[[%d;]*m", "")
							if cleaned ~= content then
								local fw = io.open(r.output, "w")
								if fw then
									fw:write(cleaned)
									fw:close()
								end
							end
						end
					end
				end
				return results
			end
			return adapter
		end

		-- Collapse neotest's virtual-text diagnostics to a single clean line.
		local neotest_ns = vim.api.nvim_create_namespace("neotest")
		vim.diagnostic.config({
			virtual_text = {
				format = function(diagnostic)
					local message = diagnostic
						.message
						:gsub("\27%[[%d;]*m", "") -- strip ANSI escape codes
						:gsub("\n", " ")
						:gsub("\t", " ")
						:gsub("%s+", " ")
						:gsub("^%s+", "")
					return message
				end,
			},
		}, neotest_ns)

		opts.consumers = opts.consumers or {}
		-- Consumer that opens the edgy trouble view on failures and closes it when all pass.
		opts.consumers.trouble = function(client)
			client.listeners.results = function(adapter_id, results, partial)
				if partial then
					return
				end
				local tree = assert(client:get_position(nil, { adapter = adapter_id }))

				local failed = 0
				for pos_id, result in pairs(results) do
					if result.status == "failed" and tree:get_key(pos_id) then
						failed = failed + 1
					end
				end
				vim.schedule(function()
					local trouble = require("trouble")
					local edgy_util = require("util.plugins.edgy")
					if edgy_util.get_current_view() == edgy_util.views.neotest then
						if failed == 0 then
							edgy_util.restore_prev_view()
						end
					else
						if failed ~= 0 then
							edgy_util.open_view("neotest")
						end
					end
				end)
				return {}
			end
		end

		-- Turn the adapter config map into instantiated, ANSI-wrapped adapter instances.
		if opts.adapters then
			local adapters = {}
			for name, config in pairs(opts.adapters or {}) do
				if type(name) == "number" then
					if type(config) == "string" then
						config = require(config)
					end
					adapters[#adapters + 1] = config
				elseif config ~= false then
					local adapter = require(name)
					if type(config) == "table" and not vim.tbl_isempty(config) then
						local meta = getmetatable(adapter)
						if adapter.setup then
							adapter.setup(config)
						elseif adapter.adapter then
							adapter.adapter(config)
							adapter = adapter.adapter
						elseif meta and meta.__call then
							adapter = adapter(config)
						else
							error("Adapter " .. name .. " does not support setup")
						end
					end
					adapters[#adapters + 1] = wrap_adapter(adapter)
				end
			end
			opts.adapters = adapters
		end

		require("neotest").setup(opts)
	end,
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
