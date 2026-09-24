--- Motion-driven multicursor dialect on top of jake-stewart/multicursor.nvim.
---
--- Upstream's demo config starts from the arrow keys; this dialect hangs off
--- one prefix instead:
---
---   gz{motion}   leave a cursor where the cursor was, land the main one
---                where the motion does (`gz}` `gzf(` `gzt.` `gzgg`)
---
--- Once two or more cursors exist, the plugin's keymap layer promotes the
--- movement keys — the bare keys spawn again, so walking the file collects
--- cursors:
---
---   w b e $ ^ …          spawn at the next motion destination, keep collecting
---   f{char} t{char}      spawn with the pending char, `gzf` works plain too
---   Q{motion}            move ONLY the main cursor — reposition without spawning
---   ]m [m                rotate which cursor is the main one
---   <Esc>                collapse back to a single cursor
---
--- The layer mappings exist only while the buffer has cursors, so which-key
--- renders the runtime-enabled set by construction — the same rule the modal
--- debug keys follow — and nothing outside a session is remapped. `flash` owns
--- `s`/`S`, gitsigns owns `]c`/`[c`, harpoon owns `<C-n>`, and all of those
--- still work mid-session: unmapped keys keep their multicursor meaning, where
--- one keystroke applies to every cursor at once.
---
--- Visual mode gets only `gz` as an operator (a cursor per selected line);
--- its motions are deliberately left alone, because extending a selection and
--- spawning from it are the same keystrokes.
---@class features.multicursor
local M = {}

local mc ---@type multicursor-nvim?

--- Motions a bare key press (or `gz`) spawns a cursor with, whitelisted because
--- `mc.addCursor` feeds the key string straight to the motion engine — a stray
--- `gzd` must not eat the next edit as an operator. `f`/`t` read their pending
--- char; `F`/`T` stay excluded so treesitter's repeatable find and its `;`
--- repeat wrapper keep working mid-session.
local MOTIONS = { "w", "W", "b", "B", "e", "E", "$", "^", "0", "{", "}", "G", "gg" }

--- Motions that take one char after the motion key.
local PENDING = { f = true, t = true }

---@return string
local function read_key()
	local ok, key = pcall(vim.fn.getcharstr)
	if not ok then
		return "" -- C-c or closing stdin: treat like <Esc>, abort the capture
	end
	return key
end

--- Reads keystrokes until they form a whitelisted motion, so multi-key motions
--- (`gg`) and beyond (`gzd`) consume exactly what they need. Aborts on `<Esc>`
--- at any step and on any key that cannot extend a known motion — a stray `d`
--- must never be eaten as an operator.
---@return string?
local function read_motion()
	local motion = ""
	while true do
		local key = read_key()
		if key == "" or motion == "" and key == "\27" then
			return nil
		end
		motion = motion .. key
		if PENDING[motion] then
			local char = read_key()
			-- The pending char must be printable; <Esc> cancels instead of finding a tab.
			if not char:match("^[%p%w%s]$") then
				return nil
			end
			return motion .. char
		end
		if vim.tbl_contains(MOTIONS, motion) then
			return motion
		end
		local extends = false
		for _, candidate in ipairs(MOTIONS) do
			if candidate:sub(1, #motion) == motion then
				extends = true
				break
			end
		end
		if not extends then
			return nil
		end
	end
end

--- Leave a cursor behind and land the main one at the motion's destination.
---@param motion string
local function spawn(motion)
	mc.addCursor(motion)
end

--- Move only the main cursor; used by `Q{motion}` to reposition without adding.
---@param motion string
local function shift(motion)
	mc.skipCursor(motion)
end

--- The `gz` handler. In visual mode the selection is the range: one cursor per
--- selected line, via the plugin's operator (it handles the placement itself).
--- In normal mode a motion is read and fed to the spawner.
function M.arm()
	if not mc then
		mc = require("multicursor-nvim")
	end
	if vim.fn.mode():match("^[vV\22]") then
		mc.addCursorOperator()
		return
	end
	local motion = read_motion()
	if not motion then
		return
	end
	spawn(motion)
end

--- Session-scoped bindings. Runs only while the buffer has cursors; every
--- shadowed key is released by the plugin when the session ends.
---@param layerSet fun(mode: string|string[], lhs: string, rhs: any, opts: table?)
local function layer(layerSet)
	for _, motion in ipairs(MOTIONS) do
		layerSet("n", motion, function()
			spawn(motion)
		end, { desc = "Cursor from " .. motion })
	end
	for char in pairs(PENDING) do
		layerSet("n", char, function()
			local read = read_motion()
			if read then
				spawn(read)
			end
		end, { desc = "Cursor from " .. char })
	end

	-- Skip: walk to where the next cursor goes without spawning there yet.
	layerSet("n", "Q", function()
		local motion = read_motion()
		if motion then
			shift(motion)
		end
	end, { desc = "Move main cursor" })

	-- Rotate. `[c`/`]c` are gitsigns hunks, so the rotation rides `m` — the
	-- default next/prev-method motions, which no cursor work needs mid-session.
	layerSet({ "n", "x" }, "]m", mc.nextCursor, { desc = "Next cursor" })
	layerSet({ "n", "x" }, "[m", mc.prevCursor, { desc = "Prev cursor" })

	-- Collapse everything back to one cursor.
	layerSet("n", "<Esc>", mc.clearCursors, { desc = "End cursors" })
end

--- One-time setup: cursors are then created by `arm()`, never by another global
--- mapping, so a plain `gz<motion>` is the only way in.
function M.setup()
	if mc then
		return
	end
	mc = require("multicursor-nvim")
	mc.setup()
	mc.addKeymapLayer(layer)
end

return M
