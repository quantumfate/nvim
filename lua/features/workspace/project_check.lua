--- Whole-project diagnostics for languages whose server only reports open files.
---
--- lua_ls, clangd, rust-analyzer and ts_ls publish diagnostics for buffers you have
--- open, so "project diagnostics" was really "diagnostics of what you happened to
--- open". The command-line tools answer for every file: `lua-language-server --check`,
--- `run-clang-tidy` over the compile database, `cargo clippy`, `go vet` (or
--- golangci-lint) and `tsc --noEmit`. Their
--- findings land as ordinary diagnostics in their own namespaces, so Trouble shows them
--- beside the servers' own, and saving a file clears its batch results — the live
--- server takes over from there.
---@class workspace.project_check
local M = {}

--- clang-tidy checks used when the project has no `.clang-tidy`.
M.DEFAULT_TIDY_CHECKS = "clang-analyzer-*,bugprone-*,-bugprone-easily-swappable-parameters"

---@class workspace.CheckItem
---@field filename string
---@field lnum integer 1-based
---@field col integer 1-based
---@field severity integer vim.diagnostic.severity
---@field message string
---@field code? string

--- Namespaces by checker name, created on first use.
---@type table<string, integer>
local namespaces = {}

---@param name string
---@return integer
local function namespace(name)
	namespaces[name] = namespaces[name] or vim.api.nvim_create_namespace("project_check_" .. name)
	return namespaces[name]
end

--- Parses `lua-language-server --check_format=json` output: a map of file URI to
--- LSP-shaped diagnostics.
---@param text string
---@return workspace.CheckItem[]
function M.parse_luals(text)
	local ok, decoded = pcall(vim.json.decode, text)
	if not ok or type(decoded) ~= "table" then
		return {}
	end
	local items = {}
	for uri, diagnostics in pairs(decoded) do
		local file = vim.uri_to_fname(uri)
		for _, d in ipairs(diagnostics) do
			table.insert(items, {
				filename = file,
				lnum = d.range.start.line + 1,
				col = d.range.start.character + 1,
				severity = d.severity or vim.diagnostic.severity.WARN,
				message = d.message,
				code = d.code,
			})
		end
	end
	return items
end

--- Parses clang-tidy output. Only `warning:` and `error:` lines are findings; `note:`
--- lines and the source excerpts are explanation. A header included from several
--- files reports the same finding once per includer, so duplicates are dropped.
---@param lines string[]
---@param dir string Directory relative paths are resolved against
---@return workspace.CheckItem[]
function M.parse_tidy(lines, dir)
	local items, seen = {}, {}
	for _, line in ipairs(lines) do
		local file, lnum, col, kind, message = line:match("^(%S+):(%d+):(%d+): (%a+): (.*)$")
		if file and (kind == "warning" or kind == "error") then
			if file:sub(1, 1) ~= "/" then
				file = vim.fs.normalize(vim.fs.joinpath(dir, file))
			end
			local code = message:match("%[([%w%-%.,]+)%]$")
			if code then
				message = vim.trim(message:sub(1, -(#code + 3)))
			end
			local key = table.concat({ file, lnum, col, message }, ":")
			if not seen[key] then
				seen[key] = true
				table.insert(items, {
					filename = file,
					lnum = tonumber(lnum),
					col = tonumber(col),
					severity = kind == "error" and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
					message = message,
					code = code,
				})
			end
		end
	end
	return items
end

--- `path` as an absolute, normalized path.
---@param path string
---@param dir string
---@return string
local function absolute(path, dir)
	if path:sub(1, 1) ~= "/" then
		path = vim.fs.joinpath(dir, path)
	end
	return vim.fs.normalize(path)
end

--- Appends `item` unless an identical finding is already in `items`.
---@param items workspace.CheckItem[]
---@param seen table<string, true>
---@param item workspace.CheckItem
local function add(items, seen, item)
	local key = table.concat({ item.filename, item.lnum, item.col, item.message }, ":")
	if not seen[key] then
		seen[key] = true
		table.insert(items, item)
	end
end

--- The first line of `text` matching `pattern`, trimmed.
---@param text string?
---@param pattern string
---@return string?
local function first_line(text, pattern)
	for line in vim.gsplit(text or "", "\n", { plain = true }) do
		if line:match(pattern) then
			return vim.trim(line)
		end
	end
end

--- Parses `cargo clippy --message-format=json`. Span paths are relative to the
--- workspace root. The bin and test targets compile the same files, so each finding
--- arrives once per target and duplicates are dropped. A build that failed with no
--- error of its own to show (a panicking build script, a broken manifest, clippy not
--- installed) is a failure, not a clean project.
---@param stdout string
---@param stderr string
---@param dir string Workspace root
---@return workspace.CheckItem[] items
---@return string? failure
function M.parse_clippy(stdout, stderr, dir)
	local items, seen = {}, {}
	local success, errors = nil, 0
	for line in vim.gsplit(stdout or "", "\n", { plain = true }) do
		local ok, msg = pcall(vim.json.decode, line, { luanil = { object = true } })
		if ok and type(msg) == "table" and msg.reason == "build-finished" then
			success = msg.success
		elseif ok and type(msg) == "table" and msg.reason == "compiler-message" then
			local m = msg.message
			local level = m.level or ""
			if level:match("^error") then
				errors = errors + 1
			end
			for _, span in ipairs(m.spans or {}) do
				-- A finding inside a macro points into the macro's source (std, a
				-- dependency); the call site is the line the user can change.
				while
					span.expansion
					and (span.file_name:match("^<") or not vim.startswith(absolute(span.file_name, dir), dir))
				do
					span = span.expansion.span
				end
				if span.is_primary and (level:match("^error") or level == "warning") then
					add(items, seen, {
						filename = absolute(span.file_name, dir),
						lnum = span.line_start,
						col = span.column_start,
						severity = level == "warning" and vim.diagnostic.severity.WARN or vim.diagnostic.severity.ERROR,
						message = m.message,
						code = m.code and m.code.code or nil,
					})
				end
			end
		end
	end
	if success == nil or (success == false and errors == 0) then
		return {}, first_line(stderr, "^error") or "cargo clippy exited without a build result"
	end
	return items
end

--- Parses `go vet` stderr: `file:line:col: message`, paths relative to the module,
--- type errors prefixed with `vet: `. `#` lines name the package being vetted.
---@param lines string[]
---@param dir string Module root
---@return workspace.CheckItem[]
function M.parse_govet(lines, dir)
	local items, seen = {}, {}
	for _, line in ipairs(lines) do
		local file, lnum, col, message = line:gsub("^vet: ", ""):match("^(%S+%.go):(%d+):(%d+): (.*)$")
		if file then
			add(items, seen, {
				filename = absolute(file, dir),
				lnum = tonumber(lnum) or 1,
				col = tonumber(col) or 1,
				severity = vim.diagnostic.severity.WARN,
				message = message,
			})
		end
	end
	return items
end

--- Parses `golangci-lint run --out-format json`: `{ Issues = [{ FromLinter, Text,
--- Severity, Pos = { Filename, Line, Column } }] }`. Returns nil when the output is not
--- that report, which means the linter did not run.
---@param text string
---@param dir string Module root
---@return workspace.CheckItem[]?
function M.parse_golangci(text, dir)
	local json = (text or ""):match("{.*}")
	local ok, decoded = pcall(vim.json.decode, json or "", { luanil = { object = true, array = true } })
	if not ok or type(decoded) ~= "table" or decoded.Report == nil and decoded.Issues == nil then
		return nil
	end
	local items, seen = {}, {}
	for _, issue in ipairs(decoded.Issues or {}) do
		add(items, seen, {
			filename = absolute(issue.Pos.Filename, dir),
			lnum = issue.Pos.Line,
			-- Column 0 means "the whole line".
			col = math.max(issue.Pos.Column or 1, 1),
			severity = issue.Severity == "error" and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
			message = issue.Text,
			code = issue.FromLinter,
		})
	end
	return items
end

--- Parses `tsc --pretty false`: `file(line,col): error TS1234: message`. Errors with no
--- location (`error TS18003: No inputs were found`) are not findings; the checker
--- reports them as the failure they are.
---@param lines string[]
---@param dir string tsconfig directory
---@return workspace.CheckItem[]
function M.parse_tsc(lines, dir)
	local items, seen = {}, {}
	for _, line in ipairs(lines) do
		local file, lnum, col, kind, code, message = line:match("^(.-)%((%d+),(%d+)%): (%a+) (TS%d+): (.*)$")
		if file then
			add(items, seen, {
				filename = absolute(file, dir),
				lnum = tonumber(lnum) or 1,
				col = tonumber(col) or 1,
				severity = kind == "error" and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
				message = message,
				code = code,
			})
		end
	end
	return items
end

--- Replaces a checker's diagnostics with `items`, one batch per file.
---@param name string
---@param items workspace.CheckItem[]
---@return integer files
function M.apply(name, items)
	local ns = namespace(name)
	vim.diagnostic.reset(ns)
	local by_file = {}
	for _, item in ipairs(items) do
		by_file[item.filename] = by_file[item.filename] or {}
		table.insert(by_file[item.filename], {
			lnum = item.lnum - 1,
			col = item.col - 1,
			severity = item.severity,
			message = item.message,
			code = item.code,
			source = name,
		})
	end
	local files = 0
	for file, diagnostics in pairs(by_file) do
		-- bufadd, not bufload: Trouble lists diagnostics of unloaded buffers, and
		-- loading every file with a finding would be a second project scan.
		local buf = vim.fn.bufadd(file)
		vim.diagnostic.set(ns, buf, diagnostics)
		files = files + 1
	end
	return files
end

--- A temporary lua_ls config: the project's `.luarc.json` plus what the editor's own
--- lua_ls setup adds, so the batch check does not report what the live server hides.
---@param root string
---@return string path
local function luals_config(root)
	local config = {}
	local luarc = vim.fs.joinpath(root, ".luarc.json")
	if vim.uv.fs_stat(luarc) then
		local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(luarc), "\n"))
		config = ok and type(decoded) == "table" and decoded or {}
	end
	local server = (require("features.lsp.servers").lua_ls or {}).settings
	local disable = vim.tbl_get(server or {}, "Lua", "diagnostics", "disable") or {}
	config.diagnostics = config.diagnostics or {}
	config.diagnostics.disable = vim.list_extend(vim.deepcopy(config.diagnostics.disable or {}), disable)
	-- A Neovim config or plugin: the runtime's types, which lazydev supplies live.
	if vim.uv.fs_stat(vim.fs.joinpath(root, "lua")) then
		config.workspace = config.workspace or {}
		config.workspace.library = vim.list_extend(vim.deepcopy(config.workspace.library or {}), {
			vim.fs.joinpath(vim.env.VIMRUNTIME, "lua"),
			"${3rd}/luv/library",
		})
	end
	local path = vim.fn.tempname() .. ".luarc.json"
	vim.fn.writefile({ vim.json.encode(config) }, path)
	return path
end

---@class workspace.Checker
---@field name string
---@field cmd string[]
---@field cwd string
---@field parse fun(res: vim.SystemCompleted): workspace.CheckItem[], string?
---@field cleanup? fun()

--- The directory of the project marker `name` for `buf`: the nearest one between the
--- buffer and `root` (the outermost with `outermost`), else one directly in `root`.
---@param buf integer
---@param root string
---@param name string
---@param outermost? boolean
---@return string?
local function marker_dir(buf, root, name, outermost)
	local path = vim.api.nvim_buf_get_name(buf)
	local found = {}
	if path ~= "" and vim.startswith(vim.fs.normalize(path), root .. "/") then
		found = vim.fs.find(name, {
			path = vim.fs.dirname(path),
			upward = true,
			stop = vim.fs.dirname(root),
			limit = math.huge,
		})
	end
	local hit = outermost and found[#found] or found[1]
	if hit then
		return vim.fs.dirname(hit)
	end
	return vim.uv.fs_stat(vim.fs.joinpath(root, name)) and root or nil
end

--- A failure reason for a run that exited non-zero without a single finding: the tool
--- did not get as far as checking.
---@param res vim.SystemCompleted
---@param items workspace.CheckItem[]
---@return string?
local function silent_failure(res, items)
	if res.code ~= 0 and #items == 0 then
		local text = (res.stderr or "") .. "\n" .. (res.stdout or "")
		return first_line(text, "%S") or ("exit code " .. res.code)
	end
end

--- The checkers that apply to the project around `buf`.
---@param buf integer
---@return workspace.Checker[]
function M.checkers(buf)
	local root = require("lib.root").get({ buf = buf })
	local out = {}

	local has_lua = vim.uv.fs_stat(vim.fs.joinpath(root, ".luarc.json"))
		or vim.fs.find(function(name)
			return name:match("%.lua$") ~= nil
		end, { path = root, type = "file", limit = 1 })[1]
	if has_lua and vim.fn.executable("lua-language-server") == 1 then
		local report = vim.fn.tempname() .. ".json"
		local config = luals_config(root)
		table.insert(out, {
			name = "lua_ls",
			cwd = root,
			cmd = {
				"lua-language-server",
				"--check=" .. root,
				"--checklevel=Warning",
				"--configpath=" .. config,
				"--check_format=json",
				"--check_out_path=" .. report,
			},
			parse = function()
				-- Exits non-zero when it found something; the report is the answer.
				local ok, lines = pcall(vim.fn.readfile, report)
				return ok and M.parse_luals(table.concat(lines, "\n")) or {}
			end,
			cleanup = function()
				pcall(vim.fn.delete, report)
				pcall(vim.fn.delete, config)
			end,
		})
	end

	local ok_c, c = pcall(require, "features.lang.c")
	local db = ok_c and c.database(buf)
	if db and vim.fn.executable("clang-tidy") == 1 then
		local dir = vim.fs.dirname(db)
		local cmd = vim.fn.executable("run-clang-tidy") == 1 and { "run-clang-tidy", "-p", dir, "-quiet" }
			or { "clang-tidy", "-p", dir, "--quiet" }
		-- Without a project .clang-tidy this build enables no checks at all ("No checks
		-- enabled"), which read as a clean project. The analyzer and bugprone checks are
		-- the ones that find real defects rather than style.
		local configured = vim.fs.find(".clang-tidy", { path = dir, upward = true, limit = 1 })[1]
		if not configured then
			table.insert(cmd, (cmd[1] == "run-clang-tidy" and "-checks=" or "--checks=") .. M.DEFAULT_TIDY_CHECKS)
		end
		if cmd[1] == "clang-tidy" then
			-- Without the parallel wrapper, every file in the database, one run.
			local decoded = vim.json.decode(table.concat(vim.fn.readfile(db), "\n"))
			for _, entry in ipairs(decoded) do
				table.insert(cmd, entry.file)
			end
		end
		table.insert(out, {
			name = "clang-tidy",
			cwd = dir,
			cmd = cmd,
			parse = function(res)
				local text = (res.stdout or "") .. "\n" .. (res.stderr or "")
				-- A tool that did not run must not look like a clean result.
				local failure = text:match("No checks enabled") or text:match("Unable to run clang%-tidy")
				if failure then
					return {}, failure
				end
				return M.parse_tidy(vim.split(text, "\n", { plain = true }), dir)
			end,
		})
	end

	-- The outermost manifest is the workspace root, which span paths are relative to.
	local cargo = marker_dir(buf, root, "Cargo.toml", true)
	if cargo and vim.fn.executable("cargo") == 1 then
		table.insert(out, {
			name = "clippy",
			cwd = cargo,
			cmd = { "cargo", "clippy", "--workspace", "--all-targets", "--message-format=json" },
			parse = function(res)
				return M.parse_clippy(res.stdout, res.stderr, cargo)
			end,
		})
	end

	local gomod = marker_dir(buf, root, "go.mod")
	if gomod and vim.fn.executable("golangci-lint") == 1 then
		-- golangci-lint runs govet among its defaults; running go vet too would list
		-- every vet finding twice.
		table.insert(out, {
			name = "golangci-lint",
			cwd = gomod,
			cmd = { "golangci-lint", "run", "--out-format", "json", "./..." },
			parse = function(res)
				local items = M.parse_golangci(res.stdout, gomod)
				if not items then
					return {}, first_line(res.stderr, "%S") or ("exit code " .. res.code)
				end
				return items
			end,
		})
	elseif gomod and vim.fn.executable("go") == 1 then
		table.insert(out, {
			name = "go vet",
			cwd = gomod,
			cmd = { "go", "vet", "./..." },
			parse = function(res)
				local items = M.parse_govet(vim.split(res.stderr or "", "\n", { plain = true }), gomod)
				return items, silent_failure(res, items)
			end,
		})
	end

	local tsconfig = marker_dir(buf, root, "tsconfig.json")
	if tsconfig then
		-- The project's own compiler first: its version is the one the code targets.
		local tsc = vim.fs.find(function(name, dir)
			return name == "node_modules" and vim.fn.executable(vim.fs.joinpath(dir, name, ".bin", "tsc")) == 1
		end, { path = tsconfig, upward = true, type = "directory", limit = 1 })[1]
		tsc = tsc and vim.fs.joinpath(tsc, ".bin", "tsc") or (vim.fn.executable("tsc") == 1 and "tsc" or nil)
		if tsc then
			table.insert(out, {
				name = "tsc",
				cwd = tsconfig,
				cmd = { tsc, "--noEmit", "--pretty", "false", "-p", tsconfig },
				parse = function(res)
					local items = M.parse_tsc(vim.split(res.stdout or "", "\n", { plain = true }), tsconfig)
					return items, silent_failure(res, items)
				end,
			})
		end
	end
	return out
end

--- Runs every applicable checker in the background and publishes the results.
---@param buf integer
function M.run(buf)
	local checkers = M.checkers(buf)
	if #checkers == 0 then
		return
	end
	local jobs = require("features.lang.jobs")
	for _, checker in ipairs(checkers) do
		local title = "check " .. checker.name
		if not jobs.running(title) then
			local finished = jobs.start(title, checker.cmd[1])
			local ok, err = pcall(vim.system, checker.cmd, { text = true, cwd = checker.cwd }, function(res)
				vim.schedule(function()
					finished()
					local items, failure = checker.parse(res)
					if checker.cleanup then
						checker.cleanup()
					end
					if failure then
						Snacks.notify.error(
							("%s did not run: %s"):format(checker.name, failure),
							{ title = "Project check" }
						)
						return
					end
					local files = M.apply(checker.name, items)
					Snacks.notify.info(
						("%s: %d finding(s) in %d file(s)"):format(checker.name, #items, files),
						{ title = "Project check" }
					)
				end)
			end)
			if not ok then
				finished()
				Snacks.notify.error(
					("%s could not start: %s"):format(checker.name, tostring(err)),
					{ title = "Project check" }
				)
			end
		end
	end
end

--- Clears a file's batch findings when it is saved: they describe the file as it was.
function M.setup()
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = vim.api.nvim_create_augroup("project_check", { clear = true }),
		callback = function(args)
			for _, ns in pairs(namespaces) do
				vim.diagnostic.reset(ns, args.buf)
			end
		end,
	})
end

return M
