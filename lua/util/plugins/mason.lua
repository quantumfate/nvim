--- Mason package helpers guarded by registry availability.
---@class util.plugins.mason
local M = {}

--- Installs each registry-available package if missing; warns about unavailable ones.
--- Snacks is a global from snacks.nvim.
---@param packages string[]
---@return string[] available In-registry packages
---@return string[] unavailable Packages absent from the registry
function M.ensure_installed(packages)
	local registry = require("mason-registry")
	local available = {}
	local unavailable = {}

	for _, pkg in ipairs(packages) do
		if registry.has_package(pkg) then
			table.insert(available, pkg)
			local p = registry.get_package(pkg)
			if not p:is_installed() then
				p:install()
			end
		else
			table.insert(unavailable, pkg)
		end
	end

	if #unavailable > 0 then
		Snacks.notify.warn("Mason: Not available (install via system): " .. table.concat(unavailable, ", "))
	end

	return available, unavailable
end

--- Keeps only packages present in the Mason registry.
---@param packages string[]
---@return string[] filtered_packages
function M.filter_available(packages)
	local registry = require("mason-registry")
	return vim.tbl_filter(function(pkg)
		return registry.has_package(pkg)
	end, packages)
end

return M
