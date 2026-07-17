--- Detects which ecosystems, build systems, and task runners a project root uses,
--- so generators tailor output without clobbering existing conventions.
---@class scaffold.detect
local M = {}

local fs = require("util.fs")

--- Root-level marker files identifying an ecosystem; checked before extension scans.
---@type table<string, string[]>
local MARKERS = {
	rust = { "Cargo.toml" },
	go = { "go.mod" },
	node = { "package.json" },
	python = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt" },
	c = { "CMakeLists.txt", "Makefile", "configure.ac", "meson.build" },
	nix = { "flake.nix", "default.nix", "shell.nix" },
	ansible = { "ansible.cfg", "playbook.yml", "playbook.yaml" },
}

--- Fallback extensions for ecosystems without a marker file (e.g. a loose script dir).
---@type table<string, string[]>
local EXTENSIONS = {
	lua = { "lua" },
	python = { "py" },
	c = { "c", "h", "cc", "cpp", "cxx", "hpp" },
	go = { "go" },
	rust = { "rs" },
	shell = { "sh", "bash" },
	yaml = { "yml", "yaml" },
	markdown = { "md", "markdown" },
	nix = { "nix" },
}

--- Build systems / task runners keyed by marker. `runner` entries block justfile
--- generation (don't duplicate an entry point); `native` come from an ecosystem.
---@type table<string, "runner"|"native">
local BUILD_MARKERS = {
	["justfile"] = "runner",
	["Justfile"] = "runner",
	["Makefile"] = "runner",
	["makefile"] = "runner",
	["GNUmakefile"] = "runner",
	["Taskfile.yml"] = "runner",
	["Taskfile.yaml"] = "runner",
	["CMakeLists.txt"] = "native",
	["meson.build"] = "native",
	["Cargo.toml"] = "native",
	["go.mod"] = "native",
	["package.json"] = "native",
}

--- Returns true if `name` exists as a readable file directly under `root`.
---@param root string Absolute project root
---@param name string Filename to probe
---@return boolean
local function has_file(root, name)
	return vim.uv.fs_stat(fs.join_paths(root, name)) ~= nil
end

--- True if any file with one of `exts` exists under `root` (early-exit scan).
---@param root string Absolute project root
---@param exts string[] Extensions without the leading dot
---@return boolean
local function has_ext(root, exts)
	local set = {}
	for _, e in ipairs(exts) do
		set[e] = true
	end
	local hits = vim.fs.find(function(name)
		local ext = name:match("%.([%w]+)$")
		return ext ~= nil and set[ext] == true
	end, { path = root, type = "file", limit = 1 })
	return #hits > 0
end

---@class scaffold.Detection
---@field root string Absolute project root
---@field ecosystems table<string, boolean> Detected language ecosystems
---@field build table<string, "runner"|"native"> Present build systems / task runners
---@field has_git boolean Whether the root is a git repository

--- Scans a project root and reports its ecosystems and build systems.
---@param root string Absolute project root to inspect
---@return scaffold.Detection
function M.scan(root)
	---@type scaffold.Detection
	local d = { root = root, ecosystems = {}, build = {}, has_git = has_file(root, ".git") }

	for eco, markers in pairs(MARKERS) do
		for _, m in ipairs(markers) do
			if has_file(root, m) then
				d.ecosystems[eco] = true
				break
			end
		end
	end

	-- Ansible is a specialisation of yaml; presence implies both.
	if has_file(root, "roles") and (has_file(root, "playbook.yml") or has_file(root, "ansible.cfg")) then
		d.ecosystems.ansible = true
	end
	if d.ecosystems.ansible then
		d.ecosystems.yaml = true
	end

	-- Fall back to extension scans only for ecosystems not already proven by a marker.
	for eco, exts in pairs(EXTENSIONS) do
		if not d.ecosystems[eco] and has_ext(root, exts) then
			d.ecosystems[eco] = true
		end
	end

	for marker, kind in pairs(BUILD_MARKERS) do
		if has_file(root, marker) then
			d.build[marker] = kind
		end
	end

	return d
end

--- Whether a generic task runner (just/make/task) already exists.
---@param d scaffold.Detection
---@return boolean
function M.has_task_runner(d)
	for _, kind in pairs(d.build) do
		if kind == "runner" then
			return true
		end
	end
	return false
end

return M
