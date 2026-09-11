--- Whole-project diagnostics for languages whose server only reports open files.
---
--- lua_ls, clangd, rust-analyzer and ts_ls publish diagnostics for buffers you have
--- open, so "project diagnostics" was really "diagnostics of what you happened to
--- open". For Lua and C the command-line tools answer for every file in a few seconds:
--- `lua-language-server --check` and `run-clang-tidy` over the compile database. Their
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
---@field parse fun(res: vim.SystemCompleted): workspace.CheckItem[]
---@field cleanup? fun()

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
						Snacks.notify.error(("%s did not run: %s"):format(checker.name, failure), { title = "Project check" })
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
				Snacks.notify.error(("%s could not start: %s"):format(checker.name, tostring(err)), { title = "Project check" })
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
