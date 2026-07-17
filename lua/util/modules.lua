--- Module loading utilities: clean require, safe require, hot reload, and lazy proxies.
---@class util.modules
local M = {}

local log = require("util.log")
local fmt = string.format

--- Copies new[k] onto old[k], warning when either side is a thread/userdata.
--- Snacks is a global from the snacks.nvim plugin.
---@param old table
---@param new table
---@param k any
local function _assign(old, new, k)
	local otype = type(old[k])
	local ntype = type(new[k])
	if (otype == "thread" or otype == "userdata") or (ntype == "thread" or ntype == "userdata") then
		Snacks.notify.warn(fmt("warning: old or new attr %s type be thread or userdata", k))
	end
	old[k] = new[k]
end

--- Deep-replaces old's contents with new's, deleting keys absent from new.
--- repeat_tbl guards against cycles across recursive calls.
---@param old table
---@param new table
---@param repeat_tbl table Set of already-processed tables
local function _replace(old, new, repeat_tbl)
	if repeat_tbl[old] then
		return
	end
	repeat_tbl[old] = true

	-- Drop keys that no longer exist in new.
	local dellist = {}
	for k, _ in pairs(old) do
		if not new[k] then
			table.insert(dellist, k)
		end
	end
	for _, v in ipairs(dellist) do
		old[v] = nil
	end

	-- Merge new keys, recursing into matching nested tables.
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
					_replace(old[k], new[k], repeat_tbl)
				else
					_assign(old, new, k)
				end
			end
		end
	end
end

--- Requires a module with its cache cleared first; keeps the old copy on failure.
---@param m string
---@return table module
M.require_clean = function(m)
	package.loaded[m] = nil
	_G[m] = nil
	local _, module = pcall(require, m)
	return module
end

--- Requires a module via pcall, logging and returning false on failure.
---@param mod string
---@return table|boolean module Module on success, false on failure
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

--- Hot-reloads a module in place, merging new contents into the existing table.
---@param mod string
---@return table|boolean module Reloaded module, or old module/false on failure
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

--- Lazy proxy that requires the module on first field access (table exports only).
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

--- Lazy proxy that requires the module only when an exported function is called.
--- Source: tjdevries/lazy-require.nvim.
---@param require_path string
---@return table proxy
function M.require_on_exported_call(require_path)
	return setmetatable({}, {
		__index = function(_, k)
			return function(...)
				return require(require_path)[k](...)
			end
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
