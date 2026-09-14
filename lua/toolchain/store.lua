--- Writes $QF_STORE/nvim/tools.json: what resolved on PATH, at which version.
--- Neovim owns the file, ansible only reads it.
---
--- $QF_STORE is the desktop's shared quantum-store directory; the editor's
--- tool inventory lives with the rest of the state (see
--- hypr/session/uwsm/env-hyprland for the one place the path is named).
---@class toolchain.store
local M = {}

-- Lazy: M.read() is just a JSON parse and is called from the dashboard at startup.
-- Only refresh() needs the registry, and that runs on idle.
local registry = require("lib.modules").require_on_index("toolchain.registry")

-- Readers refuse a shape they do not know.
local SCHEMA = 1

---@type table<string, { mtime: integer, version: string }>
local version_cache = {}

---@param path string
---@param args string[]
---@return string
local function cache_key(path, args)
	return path .. "\0" .. table.concat(args, " ")
end

--- The shared quantum-store directory, with nvim's own state dir as the
--- one step back: a tools.json the desk has not migrated still answers, and
--- the next refresh writes forward.
---@return string
function M.root()
	local env = os.getenv("QF_STORE")
	if env then
		return env
	end
	local state = os.getenv("XDG_STATE_HOME") or vim.fs.joinpath(vim.env.HOME, ".local", "state")
	return vim.fs.joinpath(state, "quantum-store")
end

---@return string
function M.path()
	return vim.fs.joinpath(M.root(), "nvim", "tools.json")
end

---@return string
local function legacy_path()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "tools.json")
end

---@return table?
function M.read()
	local ok, content = pcall(vim.fn.readfile, M.path())
	if (not ok or #content == 0) and vim.uv.fs_stat(legacy_path()) ~= nil then
		ok, content = pcall(vim.fn.readfile, legacy_path())
	end
	if not ok or #content == 0 then
		return nil
	end
	local decoded, doc = pcall(vim.json.decode, table.concat(content, "\n"))
	return decoded and doc or nil
end

local function seed_cache()
	local doc = M.read()
	for _, eco in pairs(doc and doc.ecosystems or {}) do
		for _, tool in ipairs(eco.tools or {}) do
			if tool.path and tool.version and tool.mtime and tool.probe then
				version_cache[tool.probe] = { mtime = tool.mtime, version = tool.version }
			end
		end
	end
end

---@param out string
---@return string?
local function sanitize(out)
	local first = vim.split(out, "\n", { plain = true })[1] or ""
	first = first:gsub("\27%[[0-9;]*m", ""):gsub("%s+", " ")
	first = vim.trim(first)
	if first == "" then
		return nil
	end
	return #first > 72 and (first:sub(1, 69) .. "...") or first
end

---@param path string
---@param args string[]
---@param on_done fun(version: string?)
local function probe_version(path, args, on_done)
	vim.system({ path, unpack(args) }, { text = true, timeout = 5000 }, function(res)
		on_done(sanitize((res.stdout or "") .. (res.stderr or "")))
	end)
end

--- Installed package versions, for tools that cannot report their own.
---@param on_done fun(versions: table<string, string>)
local function package_versions(on_done)
	vim.system({ "pacman", "-Q" }, { text = true }, function(res)
		local out = {}
		for _, line in ipairs(vim.split(res.stdout or "", "\n", { plain = true })) do
			local name, version = line:match("^(%S+)%s+(%S+)$")
			if name then
				out[name] = version
			end
		end
		on_done(out)
	end)
end

---@param entry { eco: string, kind: toolchain.Kind, tool: toolchain.Tool }
---@return table state Serialisable tool state, version still unfilled
local function resolve(entry)
	local tool = entry.tool
	-- A pinned path is not on PATH at all — a node entry point, say.
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
	-- Falls back for anything that cannot report a version of its own.
	local pkg_versions = {}

	-- Probe callbacks land in a fast event context, where the vim.fn calls behind the
	-- write are not allowed.
	local function settle()
		if finished or pending > 0 then
			return
		end
		finished = true
		vim.schedule(function()
			for _, eco in pairs(doc.ecosystems) do
				for _, tool in ipairs(eco.tools) do
					if not tool.version and tool.present and tool.package then
						tool.version = pkg_versions[tool.package]
						tool.version_source = tool.version and "package" or nil
					elseif tool.version then
						tool.version_source = tool.version_source or "probe"
					end
				end
			end
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

			-- Entry points are not executables; version_args = false means "do not ask".
			local probeable = want_versions and state.path and not entry.tool.path and entry.tool.version_args ~= false
			local args = entry.tool.version_args or { "--version" }
			local key = state.path and cache_key(state.path, args) or nil
			if probeable then
				state.probe = key
			end

			local cached = key and version_cache[key]
			if cached and cached.mtime == state.mtime then
				state.version = cached.version
			elseif probeable then
				pending = pending + 1
				probe_version(state.path, args, function(version)
					state.version = version
					if version and key then
						version_cache[key] = { mtime = state.mtime, version = version }
					end
					pending = pending - 1
					settle()
				end)
			end
		end
		doc.ecosystems[eco_name] = eco
	end

	pending = pending + 1
	package_versions(function(versions)
		pkg_versions = versions
		pending = pending - 1
		settle()
	end)

	settle()
end

return M
