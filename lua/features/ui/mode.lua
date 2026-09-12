--- Modal keymap manager: temporarily overrides standard bindings with scoped one-offs
--- (e.g. debug step/continue/break or review navigation), with guaranteed restore on exit.
---@class ui.mode
local M = {}

---@class ui.KeymapDef
---@field rhs string|fun() Action or command
---@field desc string Documentation
---@field mode? string Vim mode (default "n")
---@field silent? boolean

---@class ui.ModeProfile
---@field name string Unique profile name
---@field keymaps table<string, ui.KeymapDef|fun()|string>
---@field on_enter? fun(prev_mode?: string)
---@field on_exit? fun(next_mode?: string)

--- Registered mode profiles.
---@type table<string, ui.ModeProfile>
M.profiles = {}

--- Currently active mode name.
---@type string?
M.current = nil

--- Backed-up original keymaps to restore on exit.
---@type table<string, { mode: string, lhs: string, rhs?: string, callback?: fun(), opts: table }|false>
local backups = {}

--- Registers a mode profile.
---@param profile ui.ModeProfile
function M.register(profile)
	M.profiles[profile.name] = profile
end

--- Backs up an existing keymap if present.
---@param mode string
---@param lhs string
local function backup_key(mode, lhs)
	local id = mode .. ":" .. lhs
	if backups[id] ~= nil then
		return
	end
	for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
		if m.lhs == lhs then
			backups[id] = {
				mode = mode,
				lhs = lhs,
				rhs = m.rhs,
				callback = m.callback,
				opts = {
					silent = m.silent == 1,
					nowait = m.nowait == 1,
					expr = m.expr == 1,
					desc = m.desc,
				},
			}
			return
		end
	end
	backups[id] = false -- mark as non-existent originally
end

--- Enters a modal keymap profile, saving collided keymaps.
---@param name string
---@return boolean ok
function M.enter(name)
	local profile = M.profiles[name]
	if not profile then
		vim.notify("ui.mode: unknown profile " .. tostring(name), vim.log.levels.WARN)
		return false
	end

	if M.current == name then
		return true
	end

	local prev = M.current
	if M.current then
		M.exit()
	end

	M.current = name
	vim.g.active_ui_mode = name

	-- Install modal keymaps
	for lhs, def in pairs(profile.keymaps) do
		local rhs, desc, mode, silent
		if type(def) == "function" or type(def) == "string" then
			rhs, desc, mode, silent = def, "Modal: " .. lhs, "n", true
		else
			rhs = def.rhs
			desc = def.desc or ("Modal: " .. lhs)
			mode = def.mode or "n"
			silent = def.silent ~= false
		end

		backup_key(mode, lhs)
		vim.keymap.set(mode, lhs, rhs, {
			desc = desc,
			silent = silent,
			nowait = true,
		})
	end

	if profile.on_enter then
		pcall(profile.on_enter, prev)
	end

	return true
end

--- Exits the active modal keymap profile, restoring all original bindings.
---@return boolean exited
function M.exit()
	if not M.current then
		return false
	end

	local profile = M.profiles[M.current]
	local exiting_mode = M.current
	M.current = nil
	vim.g.active_ui_mode = nil

	-- Restore backed-up keymaps
	for id, saved in pairs(backups) do
		local mode, lhs = id:match("^(.-):(.*)$")
		pcall(vim.keymap.del, mode, lhs)
		if saved then
			pcall(vim.keymap.set, saved.mode, saved.lhs, saved.callback or saved.rhs or "", saved.opts)
		end
	end
	backups = {}

	if profile and profile.on_exit then
		pcall(profile.on_exit, exiting_mode)
	end

	return true
end

--- Returns the active mode name, or nil.
---@return string?
function M.active()
	return M.current
end

return M
