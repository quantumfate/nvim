--- Projects the toolchain registry into the ansible role's variables, so the role
--- and this config can never disagree about which tools exist. The generated file is
--- committed; `just toolchain-export` regenerates it and CI fails if that produces a
--- diff.
---@class toolchain.export
local M = {}

local registry = require("toolchain.registry")

--- Path of the generated vars file, relative to the repo root.
M.rel_path = "ansible/roles/nvim/vars/tools.generated.yml"

--- Quotes a scalar for YAML. Everything is quoted: package names like `no` or `on`
--- are YAML booleans unquoted, and shell commands are full of `:` and `#`.
---@param value string
---@return string
local function scalar(value)
	return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

--- Emits `key: value`, folding a long command across lines so the generated file
--- stays inside the 120-column lint limit. Folded scalars rejoin with spaces, so the
--- split points are the ` && ` seams.
---@param out string[]
---@param indent string
---@param key string
---@param value string
local function emit(out, indent, key, value)
	if #value + #key + #indent < 100 then
		table.insert(out, indent .. key .. ": " .. scalar(value))
		return
	end
	table.insert(out, indent .. key .. ": >-")
	local parts = vim.split(value, " && ", { plain = true })
	for i, part in ipairs(parts) do
		table.insert(out, indent .. "  " .. part .. (i < #parts and " &&" or ""))
	end
end

--- Renders `nvim_ecosystems` as YAML lines.
---@return string[]
local function render()
	local out = {
		"---",
		"# GENERATED FILE — do not edit.",
		"# Source: lua/toolchain/registry.lua. Regenerate with `just toolchain-export`.",
		"#",
		"# One entry per ecosystem, matching the grouping the editor and the project",
		"# scaffold both use. `packages` installs through yay (repo and AUR alike),",
		"# `bootstrap` covers what no package provides, `tools` is what the role verifies",
		"# actually resolved afterwards.",
		"nvim_ecosystems:",
	}

	for _, eco_name in ipairs(registry.ordered()) do
		local eco = registry.eco[eco_name]
		table.insert(out, "  " .. eco_name .. ":")

		local packages = registry.packages_of(eco_name)
		table.insert(out, "    packages:" .. (#packages == 0 and " []" or ""))
		for _, pkg in ipairs(packages) do
			table.insert(out, "      - " .. scalar(pkg))
		end

		if eco.bin_paths and #eco.bin_paths > 0 then
			table.insert(out, "    bin_paths:")
			for _, path in ipairs(eco.bin_paths) do
				table.insert(out, "      - " .. scalar(path))
			end
		end

		if eco.bootstrap and #eco.bootstrap > 0 then
			table.insert(out, "    bootstrap:")
			for _, step in ipairs(eco.bootstrap) do
				table.insert(out, "      - name: " .. scalar(step.name))
				emit(out, "        ", "cmd", step.cmd)
				if step.creates then
					table.insert(out, "        creates: " .. scalar(step.creates))
				end
				if step.changed_if then
					table.insert(out, "        changed_if: " .. scalar(step.changed_if))
				end
			end
		end

		local tools = registry.tools(eco_name)
		table.insert(out, "    tools:" .. (#tools == 0 and " []" or ""))
		for _, entry in ipairs(tools) do
			local pkg = registry.package_of(entry.tool)
			table.insert(out, "      - name: " .. scalar(entry.tool.name))
			table.insert(out, "        kind: " .. scalar(entry.kind))
			table.insert(out, "        bin: " .. scalar(entry.tool.bin))
			if entry.tool.path then
				table.insert(out, "        path: " .. scalar(entry.tool.path))
			end
			table.insert(out, "        package: " .. (pkg and scalar(pkg) or "null"))
			table.insert(out, "        optional: " .. tostring(entry.tool.optional or false))
		end
	end

	return out
end

--- Writes the vars file.
---@param root? string Repo root; defaults to this config's directory
---@return string path
function M.ansible(root)
	root = root or vim.fn.fnamemodify(vim.fn.stdpath("config"), ":p"):gsub("/$", "")
	local path = vim.fs.joinpath(root, M.rel_path)
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	assert(vim.fn.writefile(render(), path) == 0, "failed to write " .. path)
	return path
end

--- Path of the generated package overview.
M.doc_rel_path = "AUR-dependencies.txt"

--- Renders the human-readable package list: what to install, per ecosystem, with the
--- tool each package is there for.
---@return string[]
local function render_doc()
	local out = {
		"# External toolchain — package list",
		"#",
		"# GENERATED FILE — do not edit. Source: lua/toolchain/registry.lua.",
		"# Regenerate with `just toolchain-export`.",
		"#",
		"# Install everything with the ansible role (repo and AUR packages alike go",
		"# through yay in one transaction):",
		"#",
		"#     just provision",
		"#",
		"# Tools with no package are built by the role's bootstrap steps, listed per",
		"# ecosystem below. Plugins are lazy.nvim's business (see lazy-lock.json) and",
		"# treesitter parsers are built on demand.",
		"",
	}

	for _, eco_name in ipairs(registry.ordered()) do
		local eco = registry.eco[eco_name]
		table.insert(out, "## " .. eco_name)

		for _, pkg in ipairs(eco.sys or {}) do
			table.insert(out, ("- %-28s runtime / base"):format(pkg))
		end
		for _, entry in ipairs(registry.tools(eco_name)) do
			local pkg = registry.package_of(entry.tool)
			table.insert(
				out,
				("- %-28s %s %s"):format(pkg or "(no package)", entry.kind, entry.tool.name)
					.. (entry.tool.optional and " [optional]" or "")
			)
		end
		for _, step in ipairs(eco.bootstrap or {}) do
			table.insert(out, ("  bootstrap: %s"):format(step.cmd))
		end
		table.insert(out, "")
	end

	return out
end

--- Writes the package overview.
---@param root? string
---@return string path
function M.doc(root)
	root = root or vim.fn.fnamemodify(vim.fn.stdpath("config"), ":p"):gsub("/$", "")
	local path = vim.fs.joinpath(root, M.doc_rel_path)
	assert(vim.fn.writefile(render_doc(), path) == 0, "failed to write " .. path)
	return path
end

--- Regenerates every artefact derived from the registry.
---@param root? string
---@return string[] paths
function M.all(root)
	return { M.ansible(root), M.doc(root) }
end

return M
