--- Resolves the `async` module name per caller.
---
--- nvim-ufo (via kevinhwang91/promise-async) and refactoring.nvim (via
--- lewis6991/async.nvim) both ship `lua/async.lua`, and their APIs are
--- unrelated: ufo calls `async(fn)` on a callable table, refactoring calls
--- `async.run`/`async.wrap`/`async.await`. Lua caches one module per name, so
--- whichever plugin loads first wins the slot and the other throws.
---
--- Both capture their module in an upvalue at load time, so routing each
--- `require("async")` to the copy its caller expects is enough.
---@class util.async_shim
local M = {}

--- Plugin directory name -> the async implementation it was written against.
---@type table<string, string>
local variants = {
	["refactoring.nvim"] = "async.nvim",
	["nvim-ufo"] = "promise-async",
}

local installed = false

--- Installs the shim. Idempotent, and a no-op for every name but "async".
function M.setup()
	if installed then
		return
	end
	installed = true

	local root = vim.fn.stdpath("data") .. "/lazy/"
	---@type table<string, any>
	local cache = {}
	local base_require = require

	---@param name string
	_G.require = function(name, ...)
		if name ~= "async" then
			return base_require(name, ...)
		end

		local source = debug.getinfo(2, "S").source or ""
		for plugin, provider in pairs(variants) do
			if source:find(plugin, 1, true) then
				if cache[provider] == nil then
					local chunk = loadfile(root .. provider .. "/lua/async.lua")
					if not chunk then
						-- Provider not installed; fall back to normal resolution
						-- rather than hard-failing the caller.
						return base_require(name, ...)
					end
					cache[provider] = chunk()
				end
				return cache[provider]
			end
		end

		return base_require(name, ...)
	end
end

return M
