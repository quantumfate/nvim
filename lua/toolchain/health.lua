--- `:checkhealth toolchain`: missing tools, and binaries shadowing their package.
---@class toolchain.health
local M = {}

local registry = require("toolchain.registry")
local store = require("toolchain.store")

local SYSTEM_PREFIXES = { "/usr/bin/", "/usr/lib/", "/bin/" }

local USER_PREFIXES = { "/.cargo/bin/", "/.rustup/", "/.luarocks/bin/", "/go/bin/", "/.local/bin/" }

---@param path string
---@param prefixes string[]
---@return boolean
local function under(path, prefixes)
	for _, prefix in ipairs(prefixes) do
		if path:find(prefix, 1, true) then
			return true
		end
	end
	return false
end

--- First dotted version in a `--version` line, trimmed to `level` components.
---@param version string?
---@param level "major"|"minor"
---@return string?
local function version_key(version, level)
	if not version then
		return nil
	end
	local major, minor = version:match("(%d+)%.(%d+)")
	if not major then
		return nil
	end
	return level == "major" and major or (major .. "." .. minor)
end

--- Report every registry version pair whose members disagree.
---@param doc table Store document
local function check_version_pairs(doc)
	for _, pair in ipairs(registry.version_pairs) do
		local found = {}
		for _, tool in ipairs((doc.ecosystems[pair.eco] or {}).tools or {}) do
			if vim.tbl_contains(pair.tools, tool.name) and tool.present then
				found[tool.name] = tool.version
			end
		end

		-- A missing half is already reported as a missing tool; say nothing twice.
		local keys, labels = {}, {}
		for _, name in ipairs(pair.tools) do
			local key = version_key(found[name], pair.level)
			if not key then
				keys = nil
				break
			end
			table.insert(keys, key)
			table.insert(labels, ("%s %s"):format(name, found[name]))
		end
		if keys then
			local label = table.concat(pair.tools, " / ")
			if keys[1] == keys[2] then
				vim.health.ok(("%s agree on %s"):format(label, keys[1]))
			else
				vim.health.error(("%s version mismatch"):format(label), {
					table.concat(labels, " vs "),
					pair.why,
				})
			end
		end
	end
end

--- The registry says which servers exist; features/lsp/servers.lua says how to
--- configure them. Neither can derive the other, so the only thing keeping them in
--- step is noticing when they drift.
local function check_lsp_coverage()
	local configured = require("features.lsp.servers")
	local missing_config, missing_registry = {}, {}

	for _, name in ipairs(registry.names("lsp")) do
		if not configured[name] then
			table.insert(missing_config, name)
		end
	end

	local known = {}
	for _, name in ipairs(registry.names("lsp")) do
		known[name] = true
	end
	for name in pairs(configured) do
		if not known[name] then
			table.insert(missing_registry, name)
		end
	end

	table.sort(missing_config)
	table.sort(missing_registry)

	if #missing_config == 0 and #missing_registry == 0 then
		vim.health.ok("registry and lsp server configs agree")
		return
	end
	if #missing_config > 0 then
		vim.health.warn("in the registry, no config in features/lsp/servers.lua", missing_config)
	end
	if #missing_registry > 0 then
		vim.health.warn("configured but not in the registry, so never installed or probed", missing_registry)
	end
end

function M.check()
	vim.health.start("toolchain")

	check_lsp_coverage()

	local doc = store.read()
	if not doc then
		vim.health.warn("no store yet", { "run :ToolchainRefresh" })
		return
	end

	vim.health.info(("store: %s (written %s)"):format(doc.store, doc.generated_at))

	local missing, foreign = {}, {}
	for _, eco_name in ipairs(registry.ordered()) do
		for _, tool in ipairs((doc.ecosystems[eco_name] or {}).tools or {}) do
			if not tool.present and not tool.optional then
				table.insert(missing, ("%s (%s) — package %s"):format(tool.name, eco_name, tool.package or "none"))
			elseif tool.present and tool.package and not under(tool.path, SYSTEM_PREFIXES) then
				-- Two installs of one binary drift apart, and the wrong one wins PATH.
				if not under(tool.path, USER_PREFIXES) then
					table.insert(
						foreign,
						("%s → %s (expected the %s package)"):format(tool.name, tool.path, tool.package)
					)
				end
			end
		end
	end

	if #missing == 0 then
		vim.health.ok(("all %d required tools present"):format(doc.summary.present))
	else
		vim.health.warn(("%d tools missing"):format(#missing), missing)
	end

	check_version_pairs(doc)

	if #foreign == 0 then
		vim.health.ok("no shadowed tools")
	else
		vim.health.error("tools resolving outside their package", foreign)
	end
end

return M
