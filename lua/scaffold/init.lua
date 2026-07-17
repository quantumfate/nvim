--- Project scaffolder. Generates best-practice config for the open project, tailored
--- to its detected ecosystems. Everything derives from one wiring table
--- (scaffold.tools); pre-commit, the flake, the ansible playbook, and CI all call the
--- same `just` recipes. Non-destructive unless `--force`.
---
--- Commands:
---   :ProjectScaffold [scope...] [--force]  Generate. A scope force-includes an
---       ecosystem (rust wiring before any .rs exists) or filters to a category.
---   :ProjectDoctor    Read-only health, hygiene, and secret report.
---   :ProjectSanitize  Fix trailing whitespace, newlines, tracked junk, script perms.
---@class scaffold
local M = {}

local detect = require("scaffold.detect")
local templates = require("scaffold.templates")
local tools = require("scaffold.tools")
local fs = require("util.fs")

--- File categories for the positional category filter; kept distinct from eco names.
---@type table<string, boolean>
local CATEGORIES = {
	meta = true,
	lang = true,
	build = true,
	hooks = true,
	provision = true,
	env = true, -- nix flake devShell + .envrc
	ci = true,
	maintenance = true,
	docs = true,
	github = true,
}

--- A single file the scaffolder can emit.
---@class scaffold.Entry
---@field path string Project-relative destination
---@field category string One of CATEGORIES
---@field when fun(d: scaffold.Detection, o: scaffold.Opts): boolean Whether this entry applies
---@field content string|fun(d: scaffold.Detection, o: scaffold.Opts): string Static text or builder
---@field executable? boolean Mark the written file executable (scripts)

--- True when at least one ecosystem was detected (a real project, not an empty dir).
---@param d scaffold.Detection
---@return boolean
local function is_project(d)
	return next(d.ecosystems) ~= nil
end

--- Gate for an entry that needs one specific ecosystem present.
---@param eco string
---@return fun(d: scaffold.Detection): boolean
local function needs(eco)
	return function(d)
		return d.ecosystems[eco] == true
	end
end

--- Registry of generatable files. Order here is the order shown in previews.
---@type scaffold.Entry[]
local REGISTRY = {
	-- Universal metadata.
	{ path = ".gitignore", category = "meta", when = is_project, content = templates.gitignore },
	{ path = ".editorconfig", category = "meta", when = is_project, content = templates.editorconfig },
	{ path = ".gitmessage", category = "meta", when = is_project, content = templates.gitmessage },
	-- Language / tool configs.
	{ path = ".yamllint", category = "lang", when = needs("yaml"), content = templates.yamllint },
	{ path = ".stylua.toml", category = "lang", when = needs("lua"), content = templates.stylua },
	{ path = ".markdownlint.yaml", category = "lang", when = needs("markdown"), content = templates.markdownlint },
	{ path = ".clang-format", category = "lang", when = needs("c"), content = templates.clang_format },
	{ path = "rustfmt.toml", category = "lang", when = needs("rust"), content = templates.rustfmt },
	{ path = ".prettierrc.json", category = "lang", when = needs("node"), content = templates.prettierrc },
	{
		-- Only when there is no pyproject.toml to carry ruff's config instead.
		path = "ruff.toml",
		category = "lang",
		when = function(d)
			return d.ecosystems.python == true and vim.uv.fs_stat(fs.join_paths(d.root, "pyproject.toml")) == nil
		end,
		content = templates.ruff,
	},
	-- Task runner: only when no runner exists, so we never shadow a Makefile.
	{
		path = "justfile",
		category = "build",
		when = function(d)
			return is_project(d) and not detect.has_task_runner(d)
		end,
		content = templates.justfile,
	},
	-- Git hooks and local dev bootstrap.
	{ path = ".pre-commit-config.yaml", category = "hooks", when = is_project, content = templates.precommit },
	{
		path = "scripts/setup.sh",
		category = "hooks",
		when = is_project,
		content = templates.setup_sh,
		executable = true,
	},
	-- System toolchain provisioning (ansible, distro-agnostic).
	{ path = "scripts/provision.yml", category = "provision", when = is_project, content = templates.provision },
	-- Nix devShell: the standard, reproducible per-project toolchain.
	{ path = "flake.nix", category = "env", when = is_project, content = templates.flake },
	-- direnv glue: loads the flake devShell on nix machines, wires tool paths always.
	{ path = ".envrc", category = "env", when = is_project, content = templates.envrc },
	-- CI runs `just check` inside the flake devShell (same flake.lock as local).
	{ path = ".github/workflows/ci.yml", category = "ci", when = is_project, content = templates.ci },
	-- Maintenance & project hygiene.
	{ path = "renovate.json", category = "maintenance", when = is_project, content = templates.renovate },
	{ path = "CHANGELOG.md", category = "docs", when = is_project, content = templates.changelog },
	{
		path = ".github/ISSUE_TEMPLATE/bug_report.yml",
		category = "github",
		when = is_project,
		content = templates.issue_bug,
	},
	{
		path = ".github/ISSUE_TEMPLATE/feature_request.yml",
		category = "github",
		when = is_project,
		content = templates.issue_feature,
	},
}

---@class scaffold.Opts
---@field force boolean Overwrite existing files instead of skipping them
---@field ecosystems string[] Ecosystems to force-treat as present (chicken-and-egg)
---@field categories table<string, boolean> Category filter; empty means all

--- Returns a fully-populated options table from a possibly-partial one.
---@param opts? table
---@return scaffold.Opts
local function normalize_opts(opts)
	opts = opts or {}
	return {
		force = opts.force == true,
		ecosystems = opts.ecosystems or {},
		categories = opts.categories or {},
	}
end

---@class scaffold.PlannedFile
---@field path string Project-relative path
---@field abs string Absolute destination
---@field content string Rendered file content
---@field executable? boolean Whether to set the executable bit after writing
---@field overwrite boolean Whether this file already exists and will be replaced

--- Computes the files to generate for a project root under the given options.
--- Existing files are included only when `force` is set (then flagged overwrite).
---@param root string Absolute project root
---@param opts? scaffold.Opts
---@return scaffold.PlannedFile[] plan
---@return scaffold.Detection detection
function M.plan(root, opts)
	opts = normalize_opts(opts)
	local d = detect.scan(root)

	-- Force-included ecosystems, so a scope can be requested before its files exist.
	for _, eco in ipairs(opts.ecosystems) do
		d.ecosystems[eco] = true
	end

	local filtering = next(opts.categories) ~= nil
	---@type scaffold.PlannedFile[]
	local plan = {}
	for _, entry in ipairs(REGISTRY) do
		local pass_category = not filtering or opts.categories[entry.category]
		if pass_category and entry.when(d, opts) then
			local abs = fs.join_paths(root, entry.path)
			local exists = vim.uv.fs_stat(abs) ~= nil
			if not exists or opts.force then
				local content = type(entry.content) == "function" and entry.content(d, opts) or entry.content
				table.insert(plan, {
					path = entry.path,
					abs = abs,
					content = content --[[@as string]],
					executable = entry.executable,
					overwrite = exists,
				})
			end
		end
	end
	return plan, d
end

--- Writes a plan to disk. Parent directories are created as needed and content is
--- normalised to end with exactly one trailing newline.
---@param plan scaffold.PlannedFile[]
---@return integer written
function M.apply(plan)
	local written = 0
	for _, file in ipairs(plan) do
		vim.fn.mkdir(vim.fs.dirname(file.abs), "p")
		local text = file.content:gsub("\n+$", "") .. "\n"
		local lines = vim.split(text, "\n", { trimempty = false })
		table.remove(lines) -- drop the empty element after the trailing newline
		vim.fn.writefile(lines, file.abs)
		if file.executable then
			vim.uv.fs_chmod(file.abs, 493) -- 0755
		end
		written = written + 1
	end
	return written
end

--- Parses `:ProjectScaffold` arguments into options. Positional args select
--- ecosystems (force-present) or categories (filter); `--force`/`-f` (or `!`)
--- overwrites existing files.
---@param fargs string[]
---@param bang boolean
---@return scaffold.Opts opts
---@return string[] unknown Unrecognised tokens, for a warning
local function parse_args(fargs, bang)
	local opts = normalize_opts({ force = bang })
	local unknown = {}
	for _, arg in ipairs(fargs) do
		if arg == "--force" or arg == "-f" then
			opts.force = true
		elseif tools.eco[arg] then
			table.insert(opts.ecosystems, arg)
		elseif CATEGORIES[arg] then
			opts.categories[arg] = true
		else
			table.insert(unknown, arg)
		end
	end
	return opts, unknown
end

--- Completion for `:ProjectScaffold`: ecosystems, categories, and flags.
---@param arg_lead string
---@return string[]
local function complete(arg_lead)
	local candidates = { "--force" }
	for eco in pairs(tools.eco) do
		table.insert(candidates, eco)
	end
	for cat in pairs(CATEGORIES) do
		table.insert(candidates, cat)
	end
	return vim.tbl_filter(function(c)
		return c:find(arg_lead, 1, true) == 1
	end, candidates)
end

--- Command entry point. Builds the plan, previews it, and applies on confirmation
--- (or immediately when force/bang is set).
---@param opts scaffold.Opts
function M.run(opts)
	opts = normalize_opts(opts)
	local root = require("util.root").get()
	local plan, detection = M.plan(root, opts)

	local ecos = vim.tbl_keys(detection.ecosystems)
	table.sort(ecos)

	if #plan == 0 then
		Snacks.notify.info(("Scaffold: nothing to add (%s)"):format(table.concat(ecos, ", ")))
		return
	end

	local lines = {}
	for _, file in ipairs(plan) do
		table.insert(lines, (file.overwrite and "  ~ " or "  + ") .. file.path)
	end
	local preview = ("Scaffold for %s\nDetected: %s\n\n%s"):format(
		vim.fn.fnamemodify(root, ":~"),
		table.concat(ecos, ", "),
		table.concat(lines, "\n")
	)

	local function do_apply()
		local n = M.apply(plan)
		Snacks.notify.info(("Scaffold: wrote %d file(s)"):format(n))
	end

	-- Force still confirms when it would overwrite, unless nothing is overwritten.
	local overwrites = false
	for _, f in ipairs(plan) do
		overwrites = overwrites or f.overwrite
	end
	if opts.force and not overwrites then
		do_apply()
		return
	end

	vim.ui.select({ "Apply", "Cancel" }, { prompt = preview }, function(choice)
		if choice == "Apply" then
			do_apply()
		end
	end)
end

--- Read-only maintenance report: missing wiring, toolchain binaries absent from
--- PATH, tracked build-artefact junk, and a heuristic secret scan.
---@return nil
function M.doctor()
	local root = require("util.root").get()
	local plan, detection = M.plan(root, {})
	local report = {}

	local junk = { ".DS_Store", "node_modules/", "__pycache__/", "target/", ".venv/", "dist/" }

	local ecos = vim.tbl_keys(detection.ecosystems)
	table.sort(ecos)
	table.insert(report, "# Project doctor: " .. vim.fn.fnamemodify(root, ":~"))
	table.insert(report, "Detected: " .. (next(ecos) and table.concat(ecos, ", ") or "none"))
	table.insert(report, "")
	local base_len = #report

	if #plan > 0 then
		table.insert(report, "## Missing config (run :ProjectScaffold)")
		for _, file in ipairs(plan) do
			table.insert(report, "  - " .. file.path)
		end
		table.insert(report, "")
	end

	local missing_bins = {}
	for _, bin in ipairs(tools.required_binaries(detection)) do
		if vim.fn.executable(bin) == 0 then
			table.insert(missing_bins, bin)
		end
	end
	if #missing_bins > 0 then
		table.insert(report, "## Toolchain not on PATH (run: just provision / just dev)")
		for _, bin in ipairs(missing_bins) do
			table.insert(report, "  - " .. bin)
		end
		table.insert(report, "")
	end

	-- A flake without a lock resolves floating inputs; nix writes the lock, we flag it.
	if
		vim.uv.fs_stat(fs.join_paths(root, "flake.nix")) ~= nil
		and vim.uv.fs_stat(fs.join_paths(root, "flake.lock")) == nil
	then
		table.insert(report, "## Nix env not pinned")
		table.insert(report, "  - flake.nix has no flake.lock - run `nix flake lock` (or `just dev`)")
		table.insert(report, "")
	end

	if detection.has_git then
		-- Tracked junk.
		local tracked = vim.fn.systemlist({ "git", "-C", root, "ls-files" })
		local flagged = {}
		for _, path in ipairs(tracked) do
			for _, j in ipairs(junk) do
				if path:find(j, 1, true) then
					table.insert(flagged, path)
					break
				end
			end
		end
		if #flagged > 0 then
			table.insert(report, "## Tracked junk (run :ProjectSanitize or git rm --cached)")
			for _, path in ipairs(flagged) do
				table.insert(report, "  - " .. path)
			end
			table.insert(report, "")
		end

		-- Heuristic secret scan over tracked files (skips binaries via -I).
		local secret_re = table.concat({
			"-----BEGIN [A-Z ]+PRIVATE KEY-----",
			"AKIA[0-9A-Z]{16}",
			"(api[_-]?key|secret|token|password)[\"' ]*[:=][ ]*[\"'][A-Za-z0-9/_+-]{16,}",
		}, "|")
		-- `-e` is required because the pattern begins with "-----BEGIN"; without it
		-- git parses the leading dashes as options.
		local hits = vim.fn.systemlist({ "git", "-C", root, "grep", "-nIE", "-e", secret_re })
		if vim.v.shell_error == 0 and #hits > 0 then
			table.insert(report, "## Possible secrets (verify before publishing)")
			for i, line in ipairs(hits) do
				if i > 20 then
					table.insert(report, "  ... " .. (#hits - 20) .. " more")
					break
				end
				table.insert(report, "  - " .. line)
			end
			table.insert(report, "")
		end
	end

	if #report <= base_len then
		table.insert(report, "All clear \xe2\x9c\x94")
	end

	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, report)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf })
end

--- Returns the raw contents of `abs`, or nil if it looks binary or is unreadable.
---@param abs string
---@return string?
local function read_text(abs)
	local fh = io.open(abs, "rb")
	if not fh then
		return nil
	end
	local data = fh:read("*a") or ""
	fh:close()
	if data:find("\0", 1, true) then
		return nil -- binary
	end
	return data
end

--- Auto-fix pass (preview then confirm): trailing whitespace, final newlines,
--- `git rm --cached` for tracked junk, and the executable bit on scripts.
---@return nil
function M.sanitize()
	local root = require("util.root").get()
	local detection = detect.scan(root)
	if not detection.has_git then
		Snacks.notify.warn("Sanitize: not a git repository")
		return
	end

	local tracked = vim.fn.systemlist({ "git", "-C", root, "ls-files" })
	local junk = { ".DS_Store", "node_modules/", "__pycache__/", "target/", ".venv/", "dist/" }

	local ws_fixes = {} ---@type { abs: string, data: string }[]
	local junk_paths = {} ---@type string[]
	local chmod_paths = {} ---@type string[]

	for _, rel in ipairs(tracked) do
		local abs = fs.join_paths(root, rel)

		local is_junk = false
		for _, j in ipairs(junk) do
			if rel:find(j, 1, true) then
				is_junk = true
				break
			end
		end
		if is_junk then
			table.insert(junk_paths, rel)
		else
			local data = read_text(abs)
			if data and #data > 0 then
				local fixed = data:gsub("[ \t]+\n", "\n"):gsub("[ \t]+$", "")
				if not fixed:match("\n$") then
					fixed = fixed .. "\n"
				end
				if fixed ~= data then
					table.insert(ws_fixes, { abs = abs, data = fixed })
				end
			end
			-- Missing executable bit on a shell script.
			if rel:match("%.sh$") or rel:match("^scripts/") then
				local st = vim.uv.fs_stat(abs)
				if st and st.type == "file" and require("bit").band(st.mode, 73) == 0 then -- 0111 execute bits
					table.insert(chmod_paths, rel)
				end
			end
		end
	end

	local total = #ws_fixes + #junk_paths + #chmod_paths
	if total == 0 then
		Snacks.notify.info("Sanitize: nothing to fix \xe2\x9c\x94")
		return
	end

	local preview = { ("Sanitize %s"):format(vim.fn.fnamemodify(root, ":~")), "" }
	if #ws_fixes > 0 then
		table.insert(preview, ("whitespace/newline: %d file(s)"):format(#ws_fixes))
	end
	if #junk_paths > 0 then
		table.insert(preview, ("git rm --cached: %d path(s)"):format(#junk_paths))
	end
	if #chmod_paths > 0 then
		table.insert(preview, ("chmod +x: %d script(s)"):format(#chmod_paths))
	end

	vim.ui.select({ "Apply", "Cancel" }, { prompt = table.concat(preview, "\n") }, function(choice)
		if choice ~= "Apply" then
			return
		end
		for _, fix in ipairs(ws_fixes) do
			local fh = io.open(fix.abs, "wb")
			if fh then
				fh:write(fix.data)
				fh:close()
			end
		end
		for _, rel in ipairs(chmod_paths) do
			vim.uv.fs_chmod(fs.join_paths(root, rel), 493)
		end
		if #junk_paths > 0 then
			local args = { "git", "-C", root, "rm", "--cached", "-r", "--" }
			vim.list_extend(args, junk_paths)
			vim.fn.system(args)
		end
		Snacks.notify.info(("Sanitize: fixed %d item(s)"):format(total))
	end)
end

--- Registers the user commands. Idempotent.
---@return nil
function M.setup()
	vim.api.nvim_create_user_command("ProjectScaffold", function(args)
		local opts, unknown = parse_args(args.fargs, args.bang)
		if #unknown > 0 then
			Snacks.notify.warn("Scaffold: ignoring unknown args: " .. table.concat(unknown, ", "))
		end
		M.run(opts)
	end, {
		bang = true,
		nargs = "*",
		complete = function(arg_lead)
			return complete(arg_lead)
		end,
		desc = "Generate best-practice config ([scope...] [--force])",
	})

	vim.api.nvim_create_user_command("ProjectDoctor", function()
		M.doctor()
	end, { desc = "Report missing config, toolchain, junk, and secrets" })

	vim.api.nvim_create_user_command("ProjectSanitize", function()
		M.sanitize()
	end, { desc = "Auto-fix whitespace, newlines, tracked junk, and script perms" })
end

return M
