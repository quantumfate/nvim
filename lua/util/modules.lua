--- Module loading and reloading utilities for dynamic development
--- Provides safe module loading, hot reloading, and lazy loading capabilities
---@class util.modules
local M = {}

local log = require("util.log")
local fmt = string.format

--- Assigns the key of a new table to the old table with type safety warnings
--- Existing entries in the old table may be overridden with type mismatch warnings
---@param old table The old table to update
---@param new table The new table containing updates
---@param k any The key to assign from new to old table
local function _assign(old, new, k)
	local otype = type(old[k])
	local ntype = type(new[k])
	if (otype == "thread" or otype == "userdata") or (ntype == "thread" or ntype == "userdata") then
		Snacks.notify.warn(fmt("warning: old or new attr %s type be thread or userdata", k))
	end
	old[k] = new[k]
end

--- Recursively replaces table values with new values, deleting missing keys
--- Works recursively on nested tables to perform deep replacement operations
--- TODO: optionally keep old data
---@param old table The entries of the old table to be replaced
---@param new table The entries of the new table containing replacements
---@param repeat_tbl table A flag table to keep track of processed entries
local function _replace(old, new, repeat_tbl)
	if repeat_tbl[old] then
		-- return when an entry was already processed
		return
	end
	repeat_tbl[old] = true

	-- if a key from the old table does not exist in the new table
	-- it will be deleted from the old table
	local dellist = {}
	for k, _ in pairs(old) do
		if not new[k] then
			table.insert(dellist, k)
		end
	end
	-- deleting
	for _, v in ipairs(dellist) do
		old[v] = nil
	end

	-- iterate the new table
	for k, _ in pairs(new) do
		if not old[k] then
			old[k] = new[k]
		else
			if type(old[k]) ~= type(new[k]) then
				log.debug(
					fmt("Reloader: mismatch between old [%s] and new [%s] type for [%s]", type(old[k]), type(new[k]), k)
				)
				_assign(old, new, k)
			else
				if type(old[k]) == "table" then
					-- recurse
					_replace(old[k], new[k], repeat_tbl)
				else
					-- overwrite
					_assign(old, new, k)
				end
			end
		end
	end
end

--- Requires a module and clears any cached state of the module
--- If the require of the module fails, the cached state will be preserved
---@param m string The module path that should be clean required
---@return table module The clean required module on success, else the old module before require
M.require_clean = function(m)
	package.loaded[m] = nil
	_G[m] = nil
	local _, module = pcall(require, m)
	return module
end

--- Safely requires a module using pcall to catch errors
--- Logs debug information when module loading fails
---@param mod string The path to the module
---@return table|boolean module The module's table on success or false on failed pcall
M.require_safe = function(mod)
	local status_ok, module = pcall(require, mod)
	if not status_ok then
		local trace = debug.getinfo(2, "SL")
		local shorter_src = trace.short_src
		local lineinfo = shorter_src .. ":" .. (trace.currentline or trace.linedefined)
		local msg = fmt("%s : skipped loading [%s]", lineinfo, mod)
		log.debug(msg)
		return status_ok
	end
	return module
end

--- Hot reload a module by clearing cache and reloading with state preservation
--- Preserves cached state if module reload fails, enables live development
---@param mod string The path to the module to reload
---@return table|boolean module The reloaded module on success, old module or false on failure
M.reload = function(mod)
	if not package.loaded[mod] then
		return M.require_safe(mod)
	end

	local old = package.loaded[mod]
	package.loaded[mod] = nil
	local new = M.require_safe(mod)

	if type(old) == "table" and type(new) == "table" then
		local repeat_tbl = {}
		_replace(old, new, repeat_tbl)
	end

	package.loaded[mod] = old
	return old
end

--- Create a lazy-loading proxy that requires module only when first accessed
--- Only works for modules that export a table, enables performance optimization
---@param require_path string The module path to lazy load
---@return table proxy A metatable proxy that loads the module on first access
function M.require_on_index(require_path)
	-- code from <https://github.com/tjdevries/lazy-require.nvim/blob/bb626818ebc175b8c595846925fd96902b1ce02b/lua/lazy-require.lua#L25>
	return setmetatable({}, {
		__index = function(_, key)
			return require(require_path)[key]
		end,

		__newindex = function(_, key, value)
			require(require_path)[key] = value
		end,
	})
end

--- Create a lazy-loading proxy that requires module only when methods are called
--- Creates function wrappers that delay module loading until actual function call
---@param require_path string The module path to lazy load
---@return table proxy A metatable proxy that loads module when functions are called
---@usage
--- -- This is not loaded yet
--- local lazy_mod = lazy.require_on_exported_call('my_module')
--- local lazy_func = lazy_mod.exported_func
--- -- ... some time later
--- lazy_func(42)  -- <- Only loads the module now
function M.require_on_exported_call(require_path)
	-- https://github.com/tjdevries/lazy-require.nvim/blob/bb626818ebc175b8c595846925fd96902b1ce02b/lua/lazy-require.lua#L64
	return setmetatable({}, {
		__index = function(_, k)
			return function(...)
				return require(require_path)[k](...)
			end
		end,
	})
end

--- Check if a lazy.nvim plugin is currently loaded
--- Queries lazy.nvim's internal state to determine plugin load status
---@param name string The plugin name to check
---@return boolean is_loaded True if the plugin is loaded, false otherwise
function M.is_loaded(name)
	local Config = require("lazy.core.config")
	return Config.plugins[name] and Config.plugins[name]._.loaded
end

--- Execute a callback when a lazy.nvim plugin loads
--- Immediately executes if plugin is already loaded, otherwise waits for LazyLoad event
---@param name string The plugin name to wait for
---@param fn fun(name:string) Callback function to execute when plugin loads
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
