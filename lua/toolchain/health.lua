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

function M.check()
	vim.health.start("toolchain")

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

	if #foreign == 0 then
		vim.health.ok("no shadowed tools")
	else
		vim.health.error("tools resolving outside their package", foreign)
	end
end

return M
