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
	local roots = require("util.root").detect({
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
					Snacks.notify.warn("No linters configured for " .. ft)
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

		lint.linters_by_ft = {
			javascript = { "eslint_d" },
			typescript = { "eslint_d" },
			javascriptreact = { "eslint_d" },
			typescriptreact = { "eslint_d" },
			vue = { "eslint_d" },
			svelte = { "eslint_d" },
			-- bash_ls already does this
			-- sh = { "shellcheck" },
			-- bash = { "shellcheck" },
			markdown = { "markdownlint" },
			yaml = { "yamllint" },
			["yaml.ansible"] = { "ansible_lint" },
			dockerfile = { "hadolint" },
			-- c/cpp: clangd runs with --clang-tidy, so a second style linter would
			-- report the same findings twice.
			-- json: jsonls already reports syntax errors, a second linter only duplicates them.
		}

		-- Slow, whole-project linters: only worth running against what is on disk.
		---@type table<string, string[]>
		local write_only_events = {
			["yaml.ansible"] = { "FileType", "BufWritePost" },
		}

		-- Lint on enter/write/insert-leave, but only when the filetype has a linter.
		local group = vim.api.nvim_create_augroup("nvim-lint", { clear = true })
		local timer = assert(vim.uv.new_timer())

		--- Run the filetype's linters against `buf`, honouring the write-only list.
		---@param buf integer
		---@param event string
		local function lint_buf(buf, event)
			local ft = vim.bo[buf].filetype
			local linters = lint.linters_by_ft[ft] or {}
			if #linters == 0 then
				return
			end

			local allowed = write_only_events[ft]
			if allowed and not vim.tbl_contains(allowed, event) then
				return
			end

			-- Coalesce bursts (TextChanged fires per edit) into one linter run.
			timer:start(200, 0, function()
				vim.schedule(function()
					-- try_lint always targets the current buffer; skip if focus moved on.
					if vim.api.nvim_get_current_buf() == buf then
						lint.try_lint(nil, { cwd = lint_root(buf) })
					end
				end)
			end)
		end

		vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "BufWritePost", "InsertLeave", "TextChanged" }, {
			group = group,
			callback = function(ev)
				lint_buf(ev.buf, ev.event)
			end,
		})

		-- This plugin loads mid-BufRead, so the first buffer's FileType may already be set.
		lint_buf(vim.api.nvim_get_current_buf(), "FileType")
	end,
}
