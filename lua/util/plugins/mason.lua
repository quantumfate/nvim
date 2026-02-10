local M = {}

--- Install packages only if they exist in Mason's registry
---@param packages string[]
---@return string[] available, string[] unavailable
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
---@param packages string[]
---@return string[]
function M.filter_available(packages)
	local registry = require("mason-registry")
	return vim.tbl_filter(function(pkg)
		return registry.has_package(pkg)
	end, packages)
end

return M
