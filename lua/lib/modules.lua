--- Lazy-loading helpers for plugin modules.
---@class lib.modules
local M = {}

--- Lazy proxy that requires the module on first field access (table exports only).
--- Lets a large table sit behind a global without parsing it at startup.
--- Source: tjdevries/lazy-require.nvim.
---@param require_path string
---@return table proxy
function M.require_on_index(require_path)
	return setmetatable({}, {
		__index = function(_, key)
			return require(require_path)[key]
		end,
		__newindex = function(_, key, value)
			require(require_path)[key] = value
		end,
	})
end

--- True if the named lazy.nvim plugin is currently loaded.
---@param name string
---@return boolean is_loaded
function M.is_loaded(name)
	local Config = require("lazy.core.config")
	return Config.plugins[name] and Config.plugins[name]._.loaded
end

--- Runs fn now if the plugin is loaded, else on its LazyLoad event.
---@param name string
---@param fn fun(name:string)
function M.on_load(name, fn)
	if M.is_loaded(name) then
		fn(name)
	else
		vim.api.nvim_create_autocmd("User", {
			pattern = "LazyLoad",
			callback = function(event)
				if event.data == name then
					fn(name)
					return true
				end
			end,
		})
	end
end

return M
