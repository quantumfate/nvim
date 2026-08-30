--- Per-mode lualine colors from the Catppuccin Macchiato palette.
---
--- Design rule: the statusline is CHROME, not content. It carries no filled
--- blocks and no background of its own — it sits on the editor background and
--- is separated from the code by whitespace alone, exactly like the tmux bars
--- and the kitty window padding. The only thing that changes per mode is the
--- foreground of the outer sections, so a mode switch is a colour shift in the
--- corner of the eye rather than a slab of paint moving across the screen.
---@class util.plugins.lualine.color
-- C: pulled from the active catppuccin theme; drives every colour below.
local C = require("catppuccin.palettes").get_palette("macchiato")

--- One mode's six sections. `accent` marks the outer edges (mode + LSP);
--- everything between it recedes to overlay greys.
---@param accent string Hex colour identifying the mode
---@return table
local function sections(accent)
	return {
		a = { bg = "NONE", fg = accent, gui = "bold" },
		b = { bg = "NONE", fg = C.overlay1 },
		c = { bg = "NONE", fg = C.overlay0 },
		x = { bg = "NONE", fg = C.overlay0 },
		y = { bg = "NONE", fg = C.overlay1 },
		z = { bg = "NONE", fg = accent },
	}
end

---@type table<string, {a: table, b: table, c: table, x: table, y: table, z: table}>
return {
	normal = sections(C.mauve),
	insert = sections(C.peach),
	terminal = sections(C.green),
	command = sections(C.red),
	visual = sections(C.lavender),
	replace = sections(C.flamingo),
	-- An unfocused window says so by going quiet, not by changing shape.
	inactive = sections(C.overlay0),
}
