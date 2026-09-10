--- Colorscheme switching.
---
--- The thing that makes this work is the ColorScheme autocmd. It fires after *any*
--- scheme loads, whatever caused it — :Theme, a bare :colorscheme, a picker, a
--- background change — so the hand-written highlights in theme/highlights.lua are
--- re-applied from one place and cannot drift out of step with the scheme underneath
--- them. There is no second mechanism to keep in sync with the first.
---
--- Adding a scheme is two steps, and the second is optional:
---   1. add the plugin spec, and an entry in M.themes if the plugin's name and the
---      colorscheme's name differ
---   2. optionally write lua/theme/adapters/<name>.lua to correct the ramp and accent
---      that theme.roles derives from the scheme's own highlight groups
---@class theme
local M = {}

--- Colorscheme name -> the lazy.nvim plugin that provides it, for schemes that are
--- not loaded at startup. Schemes absent from this table still work, they just have
--- to be installed and loaded already.
---@type table<string, string>
M.themes = {
	catppuccin = "catppuccin",
	["catppuccin-latte"] = "catppuccin",
	["catppuccin-frappe"] = "catppuccin",
	["catppuccin-macchiato"] = "catppuccin",
	["catppuccin-mocha"] = "catppuccin",
}

--- Where the active choice is remembered between sessions.
---@return string
local function state_file()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "theme.txt")
end

--- Re-applies this config's own highlights on top of the active colorscheme.
local function reapply()
	local ok, err = pcall(function()
		require("theme.highlights").apply(require("theme.roles").get())
	end)
	if not ok then
		vim.notify("theme: " .. tostring(err), vim.log.levels.ERROR)
	end
end

--- Switches colorscheme and remembers the choice.
---@param name string
---@param opts? { persist?: boolean } persist defaults to true
---@return boolean ok
function M.set(name, opts)
	opts = opts or {}

	-- Load the providing plugin first; it is lazy for every scheme but the default.
	local plugin = M.themes[name]
	if plugin and not require("lib.modules").is_loaded(plugin) then
		pcall(function()
			require("lazy").load({ plugins = { plugin } })
		end)
	end

	local ok, err = pcall(vim.cmd.colorscheme, name)
	if not ok then
		vim.notify(("theme: cannot load %q (%s)"):format(name, err), vim.log.levels.ERROR)
		return false
	end

	-- reapply() is not called here: the ColorScheme autocmd above has already run.
	if opts.persist ~= false then
		pcall(vim.fn.writefile, { name }, state_file())
	end
	return true
end

--- The persisted choice, or nil on a first run.
---@return string|nil
function M.saved()
	local ok, lines = pcall(vim.fn.readfile, state_file())
	return ok and lines[1] ~= "" and lines[1] or nil
end

--- Every colorscheme currently available, whether or not it has an adapter.
---@return string[]
function M.available()
	local names = vim.fn.getcompletion("", "color")
	table.sort(names)
	return names
end

--- Registers the ColorScheme hook and the :Theme command. Called once, from lua/core.
function M.setup()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("theme_highlights", { clear = true }),
		desc = "Re-apply this config's highlights over the new colorscheme",
		callback = reapply,
	})

	vim.api.nvim_create_user_command("Theme", function(args)
		if args.args == "" then
			-- No argument: report where things stand, including whether the active
			-- scheme is being adapted or guessed at.
			local name = vim.g.colors_name or "none"
			local adapted = require("theme.roles").adapter(name) and "adapter" or "derived from its highlights"
			vim.notify(("%s (%s)"):format(name, adapted), vim.log.levels.INFO, { title = "Theme" })
			return
		end
		M.set(args.args)
	end, {
		nargs = "?",
		complete = function(lead)
			return vim.tbl_filter(function(name)
				return name:find(lead, 1, true) == 1
			end, M.available())
		end,
		desc = "Switch colorscheme (no argument reports the active one)",
	})
end

return M
