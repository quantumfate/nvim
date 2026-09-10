--- Code formatting plugin with capability-aware configuration
--- Provides external formatter integration with conditional keymap registration
---@class plugins.coding.conform
---@field formatters_by_ft table<string, string[]> Formatters mapped by filetype
---@field format_on_save? fun(bufnr: integer): table|nil Configuration for automatic formatting

---@class ConformFormatOptions
---@field async? boolean Whether to format asynchronously
---@field lsp_fallback? boolean Whether to fall back to LSP formatting
---@field timeout_ms? integer Timeout for formatting operation
---@field formatters? string[] Specific formatters to use

return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>cf",
			--- Format the buffer with conform, falling back to LSP formatting (Snacks: global notifier).
			function()
				local buf = vim.api.nvim_get_current_buf()
				local ft = vim.bo[buf].filetype
				local conform = require("conform")

				local formatters = conform.list_formatters_for_buffer(buf)
				if #formatters == 0 then
					local clients = vim.lsp.get_clients({ bufnr = buf })
					local has_lsp_formatting = false
					for _, client in ipairs(clients) do
						if client:supports_method("textDocument/formatting") then
							has_lsp_formatting = true
							break
						end
					end

					if has_lsp_formatting then
						vim.lsp.buf.format({ async = true })
						Snacks.notify.info("Formatted with LSP (no external formatter)")
					else
						Snacks.notify.warn("No formatter available for " .. ft)
					end
					return
				end

				conform.format({ async = true, lsp_fallback = true })
			end,
			mode = { "n", "v" },
			desc = "Format buffer",
		},
		{
			"<leader>cF",
			function()
				require("conform").format({ formatters = { "injected" }, timeout_ms = 3000 })
			end,
			mode = { "n", "v" },
			desc = "Format injected langs",
		},
	},
	--- Built at spec-eval so `opts` stays a plain table. The filetype map comes from
	--- the toolchain registry, which is also what the ansible role installs and what
	--- :ToolchainStatus probes, so a formatter cannot be configured here and missing
	--- from the machine's package list.
	opts = function()
		local registry = require("toolchain.registry")
		local by_ft = registry.by_ft("fmt")

		-- conform runs every formatter in a list. Where the list is alternatives rather
		-- than a pipeline (prettierd falling back to prettier) it must stop at the first
		-- one that works instead; where it is a pipeline (ruff imports then ruff format,
		-- goimports then gofmt) every stage still runs.
		for ft in pairs(registry.alt_fts("fmt")) do
			by_ft[ft].stop_after_first = true
		end

		-- Entries the registry cannot express: one runs on every buffer, one is chosen
		-- by file extension rather than filetype, and one has no ecosystem.
		by_ft.just = { "just" }
		-- `.zon` files carry filetype `zig`, but their grammar is not Zig's.
		by_ft.zig = function(bufnr)
			return { vim.api.nvim_buf_get_name(bufnr):sub(-4) == ".zon" and "zonfmt" or "zigfmt" }
		end
		by_ft["_"] = { "trim_whitespace" } -- filetypes with no formatter of their own
		by_ft["*"] = { "codespell" } -- every buffer, on top of whatever else ran

		return {
			formatters_by_ft = by_ft,
			--- Decide format-on-save per buffer; nil skips it. Honours vim.g/vim.b disable toggles.
			format_on_save = function(bufnr)
				local ignore_filetypes = { "sql" }
				if vim.tbl_contains(ignore_filetypes, vim.bo[bufnr].filetype) then
					return
				end
				-- vim.g/vim.b.disable_autoformat: toggles set by the Format* user commands below.
				if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
					return
				end
				return {
					timeout_ms = 3000,
					lsp_fallback = true,
				}
			end,
			formatters = {
				injected = { options = { ignore_errors = true } },
				-- Auto-fixes ansible-lint rules (FQCN, key order, deprecated syntax). Rewrites the
				-- file in place rather than a stream, so it is opt-in via :AnsibleFix, never on save.
				ansible_fix = {
					command = "ansible-lint",
					args = { "--fix", "--nocolor", "--offline", "$FILENAME" },
					stdin = false,
					-- Keep the real basename in the temp copy; ansible-lint classifies files by path.
					tmpfile_format = ".conform.$RANDOM.$FILENAME",
					exit_codes = { 0, 2 },
				},
				-- Zig ships its formatter with the compiler; reads stdin, writes stdout.
				zigfmt = {
					command = "zig",
					args = { "fmt", "--stdin" },
					stdin = true,
				},
				-- Same formatter, ZON grammar. Over stdin there is no extension to infer
				-- it from, so the mode has to be stated.
				zonfmt = {
					command = "zig",
					args = { "fmt", "--stdin", "--zon" },
					stdin = true,
				},
				shfmt = {
					prepend_args = { "-i", "4" }, -- 4 space indent
				},
				prettierd = {
					env = {
						PRETTIERD_LOCAL_PRETTIER_ONLY = "1",
					},
				},
				-- conform picks the first formatter that is merely *installed*, so an
				-- unguarded deno would reformat every npm project on this machine.
				deno_fmt = {
					condition = function(_, ctx)
						return require("lib.root").detectors.pattern(ctx.buf, { "deno.json", "deno.jsonc" })[1] ~= nil
					end,
				},
			},
		}
	end,
	--- Register :FormatDisable/:FormatEnable/:FormatToggle to control format-on-save.
	init = function()
		vim.api.nvim_create_user_command("AnsibleFix", function()
			if vim.fn.executable("ansible-lint") == 0 then
				Snacks.notify.warn("ansible-lint not installed")
				return
			end
			-- conform runs it against a temp copy and reads the result back into the buffer.
			require("conform").format({ formatters = { "ansible_fix" }, timeout_ms = 15000 }, function(err)
				if err then
					Snacks.notify.error("ansible-lint --fix: " .. err)
					return
				end
				vim.cmd.update()
				Snacks.notify.info("Applied ansible-lint fixes")
			end)
		end, { desc = "Apply ansible-lint --fix to the current file" })

		vim.api.nvim_create_user_command("FormatDisable", function(args)
			if args.bang then
				vim.b.disable_autoformat = true
			else
				vim.g.disable_autoformat = true
			end
			Snacks.notify.info("Format on save disabled")
		end, { bang = true, desc = "Disable format on save (bang for buffer only)" })

		vim.api.nvim_create_user_command("FormatEnable", function()
			vim.b.disable_autoformat = false
			vim.g.disable_autoformat = false
			Snacks.notify.info("Format on save enabled")
		end, { desc = "Enable format on save" })

		vim.api.nvim_create_user_command("FormatToggle", function(args)
			if args.bang then
				vim.b.disable_autoformat = not vim.b.disable_autoformat
			else
				vim.g.disable_autoformat = not vim.g.disable_autoformat
			end
			local status = vim.g.disable_autoformat and "disabled" or "enabled"
			Snacks.notify.info("Format on save " .. status)
		end, { bang = true, desc = "Toggle format on save" })
	end,
}
