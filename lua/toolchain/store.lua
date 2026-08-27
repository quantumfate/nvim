--- Machine-readable state of the external toolchain, written to
--- `$XDG_STATE_HOME/nvim/tools.json` for other programs (quickshell status bars,
--- dashboards, update hooks) to read. Neovim owns this file: ansible installs the
--- tools, this module reports what actually resolved on PATH.
---
--- The write is atomic (tmp + rename), so a reader never sees a partial document.
---@class toolchain.store
local M = {}

local registry = require("toolchain.registry")

--- Bumped when the document shape changes, so readers can refuse what they cannot parse.
local SCHEMA = 1

--- Version probes are slow; a tool's version is re-read only when its binary changed.
---@type table<string, { mtime: integer, version: string }>
local version_cache = {}

--- Absolute path of the store.
---@return string
function M.path()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "tools.json")
end

--- Previously written document, or nil when absent or unreadable.
---@return table?
function M.read()
	local ok, content = pcall(vim.fn.readfile, M.path())
	if not ok or #content == 0 then
		return nil
	end
	local decoded, doc = pcall(vim.json.decode, table.concat(content, "\n"))
	return decoded and doc or nil
end

--- Seeds the in-memory version cache from a previous run, so a restart does not
--- re-probe every binary.
local function seed_cache()
	local doc = M.read()
	for _, eco in pairs(doc and doc.ecosystems or {}) do
		for _, tool in ipairs(eco.tools or {}) do
			if tool.path and tool.version and tool.mtime then
				version_cache[tool.path] = { mtime = tool.mtime, version = tool.version }
			end
		end
	end
end

--- First line of `<bin> --version`, trimmed. Tools disagree wildly on format, so the
--- raw line is kept rather than parsed into components.
---@param path string
---@param args string[]
---@param on_done fun(version: string?)
local function probe_version(path, args, on_done)
	vim.system({ path, unpack(args) }, { text = true, timeout = 5000 }, function(res)
		local out = (res.stdout or "") .. (res.stderr or "")
		local first = vim.split(out, "\n", { plain = true })[1] or ""
		on_done(vim.trim(first) ~= "" and vim.trim(first) or nil)
	end)
end

--- Resolves one registry entry against the filesystem.
---@param entry { eco: string, kind: toolchain.Kind, tool: toolchain.Tool }
---@return table state Serialisable tool state, version still unfilled
local function resolve(entry)
	local tool = entry.tool
	-- A tool pinned to an absolute path is not on PATH at all (a node entry point,
	-- for instance); everything else is looked up the way a shell would.
	local path = tool.path and vim.fn.expand(tool.path) or vim.fn.exepath(tool.bin)
	if tool.path and vim.uv.fs_stat(path) == nil then
		path = ""
	end
	local stat = path ~= "" and vim.uv.fs_stat(path) or nil
	return {
		name = tool.name,
		kind = entry.kind,
		ecosystem = entry.eco,
		binary = tool.bin,
		entry_point = tool.path and path ~= "" and path or nil,
		package = registry.package_of(tool),
		optional = tool.optional or false,
		present = path ~= "",
		path = path ~= "" and path or nil,
		mtime = stat and stat.mtime.sec or nil,
	}
end

--- Writes `doc` to the store atomically.
---@param doc table
---@return boolean ok
local function write(doc)
	local path = M.path()
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	local tmp = path .. ".tmp"
	local encoded = vim.json.encode(doc)
	if vim.fn.writefile({ encoded }, tmp) ~= 0 then
		return false
	end
	return vim.uv.fs_rename(tmp, path) and true or false
end

--- Rebuilds the store from the registry and the current PATH.
---
--- Version probes run concurrently and the file is written once they all report, so
--- the callback fires after the store is on disk.
---@param opts? { versions?: boolean } versions defaults to true
---@param on_done? fun(doc: table)
function M.refresh(opts, on_done)
	opts = opts or {}
	local want_versions = opts.versions ~= false
	if vim.tbl_isempty(version_cache) then
		seed_cache()
	end

	local doc = {
		schema = SCHEMA,
		generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		generated_by = "nvim " .. tostring(vim.version()),
		host = vim.uv.os_gethostname(),
		store = M.path(),
		ecosystems = {},
		summary = { total = 0, present = 0, missing = 0, missing_tools = {} },
	}

	local pending = 0
	local finished = false

	--- Writes and reports once every outstanding probe has landed. The body is
	--- scheduled because probe callbacks land in a fast event context, where the
	--- vim.fn calls behind the write are not allowed.
	local function settle()
		if finished or pending > 0 then
			return
		end
		finished = true
		vim.schedule(function()
			table.sort(doc.summary.missing_tools)
			write(doc)
			if on_done then
				on_done(doc)
			end
		end)
	end

	for _, eco_name in ipairs(registry.ordered()) do
		local eco = { tools = {}, packages = registry.packages_of(eco_name), present = 0, missing = 0 }
		for _, entry in ipairs(registry.tools(eco_name)) do
			local state = resolve(entry)
			table.insert(eco.tools, state)

			doc.summary.total = doc.summary.total + 1
			if state.present then
				eco.present = eco.present + 1
				doc.summary.present = doc.summary.present + 1
			else
				eco.missing = eco.missing + 1
				doc.summary.missing = doc.summary.missing + 1
				if not state.optional then
					table.insert(doc.summary.missing_tools, state.name)
				end
			end

			local cached = state.path and version_cache[state.path]
			if cached and cached.mtime == state.mtime then
				state.version = cached.version
			-- Entry points are not executables, so there is nothing to ask for a version.
			elseif want_versions and state.path and not entry.tool.path then
				pending = pending + 1
				probe_version(state.path, entry.tool.version_args or { "--version" }, function(version)
					state.version = version
					if version and state.path then
						version_cache[state.path] = { mtime = state.mtime, version = version }
					end
					pending = pending - 1
					settle()
				end)
			end
		end
		doc.ecosystems[eco_name] = eco
	end

	settle()
end

return M
