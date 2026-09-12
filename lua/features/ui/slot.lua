--- Mutually exclusive slot engine for editor regions (sidebar, dock, aux).
--- Ensures only one view occupies a slot at any time, supporting history and toggling.
---@class ui.slot
---@field name string Slot identifier (e.g. "sidebar", "dock")
---@field views table<string, ui.SlotView> Registered views
---@field history string[] View history stack
---@field active_name? string Currently active view name
---@field active_win? integer Window holding the active view
local Slot = {}
Slot.__index = Slot

---@class ui.SlotView
---@field title string Human-readable title
---@field ft? string|string[] Filetype(s) identifying this view's buffer
---@field open string|fun(ctx?: table): integer? Command or function opening the view
---@field close? string|fun(win?: integer) Command or function closing the view
---@field on_enter? fun(win: integer, buf: integer) Hook when view is focused

--- Creates a new mutually exclusive slot manager.
---@param name string Slot name
---@param views? table<string, ui.SlotView>
---@return ui.slot
function Slot.new(name, views)
	local self = setmetatable({}, Slot)
	self.name = name
	self.views = views or {}
	self.history = {}
	self.active_name = nil
	self.active_win = nil
	return self
end

--- Registers a view in the slot.
---@param name string View name
---@param spec ui.SlotView View specification
function Slot:register(name, spec)
	self.views[name] = spec
end

--- Finds the currently open view's window, if any.
---@return string? name, integer? win
function Slot:find_open()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			local ft = vim.bo[buf].filetype
			for name, view in pairs(self.views) do
				local fts = type(view.ft) == "table" and view.ft or { view.ft }
				---@cast fts string[]
				if vim.tbl_contains(fts, ft) then
					return name, win
				end
			end
		end
	end
	return nil, nil
end

--- Closes the currently active view in the slot.
function Slot:close()
	local cur_name, cur_win = self:find_open()
	local name = cur_name or self.active_name
	if not name then
		return
	end

	local view = self.views[name]
	if view and view.close then
		if type(view.close) == "function" then
			view.close(cur_win)
		else
			pcall(vim.cmd --[[@as function]], view.close)
		end
	elseif cur_win and vim.api.nvim_win_is_valid(cur_win) then
		pcall(vim.api.nvim_win_close, cur_win, false)
	end

	self.active_name = nil
	self.active_win = nil
end

--- Opens a view in the slot, closing any currently active view first.
---@param name string View name to open
---@param ctx? table Optional context passed to open
---@return integer? win
function Slot:open(name, ctx)
	local view = self.views[name]
	if not view then
		vim.notify(("ui.slot %s: unknown view %q"):format(self.name, name), vim.log.levels.WARN)
		return nil
	end

	local cur_name, cur_win = self:find_open()
	if cur_name == name and cur_win and vim.api.nvim_win_is_valid(cur_win) then
		self.active_name = name
		self.active_win = cur_win
		return cur_win
	end

	-- Push previous view to history if different
	if cur_name and cur_name ~= name then
		table.insert(self.history, cur_name)
		self:close()
	end

	local win = nil
	if type(view.open) == "function" then
		win = view.open(ctx)
	else
		pcall(vim.cmd --[[@as function]], view.open)
	end

	-- Locate the newly opened window
	local _, detected_win = self:find_open()
	self.active_name = name
	self.active_win = win or detected_win

	if self.active_win and view.on_enter then
		local buf = vim.api.nvim_win_get_buf(self.active_win)
		view.on_enter(self.active_win, buf)
	end

	return self.active_win
end

--- Toggles a view in the slot: closes if active, opens if not.
---@param name string
---@param ctx? table
---@return boolean opened True if view is now open
function Slot:toggle(name, ctx)
	local cur_name, cur_win = self:find_open()
	if cur_name == name and cur_win and vim.api.nvim_win_is_valid(cur_win) then
		self:close()
		return false
	end
	self:open(name, ctx)
	return true
end

--- Returns to the previous view in history.
---@return string? restored
function Slot:back()
	if #self.history == 0 then
		self:close()
		return nil
	end
	local prev = table.remove(self.history)
	self:open(prev)
	return prev
end

--- Focuses the active view window in this slot.
---@return boolean focused
function Slot:focus()
	local _, win = self:find_open()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_set_current_win(win)
		return true
	end
	return false
end

return Slot
