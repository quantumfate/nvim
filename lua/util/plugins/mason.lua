--- Mason utility module for package management
--- Provides functions to ensure packages are installed and filter available packages
---@class util.plugins.mason
local M = {}

--- Install packages only if they exist in Mason's registry
--- Checks each package against the registry and installs missing ones
---@param packages string[] List of package names to ensure are installed
---@return string[] available List of packages that are available in Mason registry
---@return string[] unavailable List of packages not found in Mason registry
function M.ensure_installed(packages)
	local registry = require("mason-registry")
	local available = {}
	local unavailable = {}

	for _, pkg in ipairs(packages) do
		if registry.has_package(pkg) then
			table.insert(available, pkg)
			-- Install if not already installed
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

--- Filter list to only Mason-available packages
--- Removes packages that are not available in the Mason registry
---@param packages string[] List of package names to filter
---@return string[] filtered_packages List containing only packages available in Mason
function M.filter_available(packages)
	local registry = require("mason-registry")
	return vim.tbl_filter(function(pkg)
		return registry.has_package(pkg)
	end, packages)
end

return M
