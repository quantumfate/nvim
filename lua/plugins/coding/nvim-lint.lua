--- Linting plugin with capability-aware configuration
--- Provides external linter integration with conditional keymap registration
---@class plugins.coding.nvim_lint
---@field linters_by_ft table<string, string[]> Linters mapped by filetype
---@field setup fun(): nil

--- Closest project root, so linters read the project's own config (.ansible-lint,
--- ansible.cfg) and resolve role/collection paths instead of nvim's cwd.
---@param buf integer
---@return string
local function lint_root(buf)
	-- detect(), not get(): get() ignores a custom spec and caches under the default one.
	local roots = require("lib.root").detect({
		buf = buf,
		all = false,
		-- Linter config beats the LSP's idea of the workspace; cwd ends the chain.
		spec = { { "ansible.cfg", ".ansible-lint", "galaxy.yml", ".git" }, "cwd" },
	})
	return roots[1].paths[1]
end
return {
	"mfussenegger/nvim-lint",
	event = { "User FileOpened" },
	keys = {
		{
			"<leader>cl",
			--- Lint the current buffer, reporting which linters ran (Snacks: global notifier).
			function()
				local lint = require("lint")
				local ft = vim.bo.filetype
				local linters = lint.linters_by_ft[ft] or {}

				if #linters == 0 then
					-- Several filetypes have no nvim-lint entry on purpose, because
					-- something else already reports the same findings. Saying which is
					-- the difference between "configured wrong" and "already covered".
					local covered = {
						c = "clangd runs clang-tidy",
						cpp = "clangd runs clang-tidy",
						lua = "lua_ls reports these",
						sh = "bash-language-server runs shellcheck",
						bash = "bash-language-server runs shellcheck",
						json = "jsonls reports syntax errors",
						rust = "rust-analyzer and bacon report these",
						zig = "zls reports these",
					}
					local why = covered[ft]
					if why then
						Snacks.notify.info(
							("No separate linter for %s — %s.\nA second pass would double every finding."):format(
								ft,
								why
							),
							{ title = "Lint" }
						)
					else
						Snacks.notify.warn("No linters configured for " .. ft, { title = "Lint" })
					end
					return
				end

				lint.try_lint(nil, { cwd = lint_root(vim.api.nvim_get_current_buf()) })
				Snacks.notify.info("Linting with: " .. table.concat(linters, ", "))
			end,
			desc = "Lint buffer",
		},
	},
	--- Map filetypes to linters and lint automatically on edit/write.
	config = function()
		local lint = require("lint")

		-- ansible-lint reports every rule at INFO out of the box and runs from nvim's cwd,
		-- so role/collection paths and .ansible-lint config go unread. Parse its codeclimate
		-- JSON instead: real severities, rule ids as diagnostic codes, project root as cwd.
		local ansible_severity = {
			blocker = vim.diagnostic.severity.ERROR,
			critical = vim.diagnostic.severity.ERROR,
			major = vim.diagnostic.severity.WARN,
			minor = vim.diagnostic.severity.WARN,
			info = vim.diagnostic.severity.INFO,
		}

		lint.linters.ansible_lint = vim.tbl_extend("force", lint.linters.ansible_lint, {
			args = { "--nocolor", "--offline", "-f", "json" },
			--- Turn ansible-lint's codeclimate JSON into diagnostics.
			---@param output string
			---@return vim.Diagnostic[]
			parser = function(output)
				local ok, issues = pcall(vim.json.decode, output)
				if not ok or type(issues) ~= "table" then
					return {}
				end

				return vim.tbl_map(function(issue)
					-- Rules report either a bare line ("lines") or a line/column pair ("positions").
					local loc = issue.location or {}
					local pos = loc.positions and loc.positions.begin or {}
					local line = pos.line or (loc.lines and loc.lines.begin) or 1
					return {
						lnum = math.max(line - 1, 0),
						col = math.max((pos.column or 1) - 1, 0),
						severity = ansible_severity[issue.severity] or vim.diagnostic.severity.WARN,
						source = "ansible-lint",
						code = issue.check_name,
						message = issue.description or issue.check_name or "ansible-lint",
					}
				end, issues)
			end,
		})

		-- From the toolchain registry, so a linter is wired to a filetype in the same
		-- table that installs it and probes for it. Filetypes deliberately left out
		-- there: sh/bash (bash-language-server already runs shellcheck), c/cpp (clangd
		-- runs with --clang-tidy), json (jsonls reports syntax errors), and lua (lua_ls).
		-- first_alt_only: nvim-lint runs every linter in a list, so eslint_d's plain-eslint
		-- fallback must not be run alongside it.
		lint.linters_by_ft = require("toolchain.registry").by_ft("lint", { first_alt_only = true })

		-- Slow, whole-project linters: only worth running against what is on disk.
		---@type table<string, string[]>
		local write_only_events = {
			["yaml.ansible"] = { "FileType", "BufWritePost" },
		}

		local group = vim.api.nvim_create_augroup("nvim-lint", { clear = true })

		-- One timer per buffer. A single shared timer meant a burst of edits in one
		-- buffer cancelled the pending run of every other.
		---@type table<integer, uv.uv_timer_t>
		local timers = {}

		vim.api.nvim_create_autocmd("BufDelete", {
			group = group,
			callback = function(ev)
				local timer = timers[ev.buf]
				if timer then
					timer:stop()
					timer:close()
					timers[ev.buf] = nil
				end
			end,
		})

		--- Run the filetype's linters against `buf`, honouring the write-only list.
		---@param buf integer
		---@param event string
		local function lint_buf(buf, event)
			-- Generated scratch buffers (:ProjectDoctor's report, diff previews) carry a
			-- real filetype but no file, and linting them decorates output nobody can fix.
			if vim.bo[buf].buftype ~= "" or not vim.bo[buf].modifiable then
				return
			end

			local ft = vim.bo[buf].filetype
			if #(lint.linters_by_ft[ft] or {}) == 0 then
				return
			end

			local allowed = write_only_events[ft]
			if allowed and not vim.tbl_contains(allowed, event) then
				return
			end

			-- Coalesce bursts (InsertLeave can fire repeatedly) into one linter run.
			local timer = timers[buf]
			if not timer then
				timer = assert(vim.uv.new_timer())
				timers[buf] = timer
			end
			timer:start(200, 0, function()
				vim.schedule(function()
					-- try_lint always targets the current buffer; skip if focus moved on.
					if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() == buf then
						lint.try_lint(nil, { cwd = lint_root(buf) })
					end
				end)
			end)
		end

		-- TextChanged and BufEnter are deliberately absent: they re-ran every linter on
		-- every keystroke and every window switch, for diagnostics that only change when
		-- an edit is finished.
		vim.api.nvim_create_autocmd({ "FileType", "BufWritePost", "InsertLeave" }, {
			group = group,
			callback = function(ev)
				lint_buf(ev.buf, ev.event)
			end,
		})

		-- This plugin loads mid-BufRead, so the first buffer's FileType may already be set.
		lint_buf(vim.api.nvim_get_current_buf(), "FileType")
	end,
}
