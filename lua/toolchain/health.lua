--- `:checkhealth toolchain` — what is installed, what is missing, and where each tool
--- came from. Reports a tool resolving outside the system prefixes as an ownership
--- problem: two installs of the same binary drift apart and the wrong one wins PATH.
---@class toolchain.health
local M = {}

local registry = require("toolchain.registry")
local store = require("toolchain.store")

--- Prefixes a system-managed tool is expected to live under.
local SYSTEM_PREFIXES = { "/usr/bin/", "/usr/lib/", "/bin/" }

--- Prefixes owned by a per-user toolchain (rustup, cargo, luarocks, go).
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
				-- A packaged tool resolving out of a user prefix means something else
				-- installed it too and is shadowing the system copy.
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
