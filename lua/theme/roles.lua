--- The colour contract every highlight in this config is written against.
---
--- The anchor is not a colour, it is a *ramp with fixed arity*: eight steps from the
--- editor background to the foreground. Every colorscheme has one — catppuccin spells
--- it base/surface0..2/overlay0..1/subtext0/text, gruvbox spells it bg0..bg4/gray/fg1,
--- tokyonight spells it something else again. Writing highlights against step numbers
--- instead of a scheme's private vocabulary is what makes them survive a switch, and
--- what keeps the gradient coherent: "one step off the background" stays true whatever
--- the colours are.
---
--- Adapters are optional. With no adapter, `M.derive()` reads the ramp back out of the
--- highlight groups the active scheme just defined, so an unknown colorscheme still
--- gets every override, only approximated. An adapter exists to correct that guess,
--- never to enable it.
---@class theme.roles
local M = {}

local color = require("theme.color")

---@class theme.Roles
---@field ramp integer[] Eight steps, background (1) to foreground (8)
---@field accent integer The one colour that marks the active thing on screen
---@field ok integer
---@field warn integer
---@field err integer
---@field info integer
---@field hint integer
---@field changed integer Modified-but-not-broken: dirty buffers, changed hunks
---@field dark boolean Whether ramp[1] is darker than ramp[8]

--- Fractions along background -> foreground for the ramp steps a scheme does not
--- supply directly. Weighted towards the background: steps 2-4 are structure
--- (indent guides, borders, separators) and must stay quiet, while 5-7 are metadata
--- text and have to be readable.
local FRACTIONS = { 0, 0.08, 0.16, 0.26, 0.42, 0.55, 0.78, 1 }

--- Reads the ramp out of the highlight groups the active colorscheme defines.
---
--- Only the two endpoints are ever guessed at: Normal is defined by every scheme
--- that works at all. The middle steps prefer real values where a scheme provides
--- something meaningful (CursorLine and Visual are the conventional first two steps
--- off the background, Comment is the conventional metadata grey) and are otherwise
--- interpolated, which is what keeps the result a gradient rather than a set.
---@return theme.Roles
function M.derive()
	local bg = color.first({ "Normal", "NormalFloat" }, "bg") or 0x1e1e2e
	local fg = color.first({ "Normal", "NormalFloat" }, "fg") or 0xcdd6f4
	local dark = color.luminance(bg) < color.luminance(fg)

	local ramp = {}
	for i, fraction in ipairs(FRACTIONS) do
		ramp[i] = color.blend(bg, fg, fraction)
	end

	-- Prefer what the scheme actually says over the interpolation.
	ramp[2] = color.first({ "CursorLine", "ColorColumn" }, "bg") or ramp[2]
	ramp[3] = color.first({ "Visual", "PmenuSel" }, "bg") or ramp[3]
	ramp[6] = color.first({ "Comment", "NonText" }, "fg") or ramp[6]
	ramp[8] = fg

	-- Those borrowed values are only useful if they still form a gradient. A scheme
	-- whose Visual is a bright fill breaks the order; one whose CursorLine is just the
	-- background (as this config sets it) collapses a step onto its neighbour and
	-- silently loses a level of structure. Either way, fall back to interpolation.
	local MIN_STEP = 0.02 -- luminance apart, or the two steps are not distinguishable
	for i = 2, 7 do
		local lum = color.luminance(ramp[i])
		local lo, hi = color.luminance(ramp[i - 1]), color.luminance(ramp[i + 1])
		local ordered = dark and (lum >= lo and lum <= hi) or not dark and (lum <= lo and lum >= hi)
		if not ordered or math.abs(lum - lo) < MIN_STEP then
			ramp[i] = color.blend(bg, fg, FRACTIONS[i])
		end
	end

	return {
		ramp = ramp,
		dark = dark,
		-- The accent is whatever the scheme already uses to mean "this one".
		accent = color.first({ "Function", "Special", "Statement", "Title", "Identifier" }, "fg") or ramp[8],
		ok = color.first({ "DiagnosticOk", "DiffAdd", "Added", "String" }, "fg") or 0xa6e3a1,
		warn = color.first({ "DiagnosticWarn", "WarningMsg", "DiffChange" }, "fg") or 0xf9e2af,
		err = color.first({ "DiagnosticError", "ErrorMsg", "DiffDelete" }, "fg") or 0xf38ba8,
		info = color.first({ "DiagnosticInfo", "MoreMsg" }, "fg") or 0x89b4fa,
		hint = color.first({ "DiagnosticHint", "Comment" }, "fg") or 0x94e2d5,
		changed = color.first({ "DiagnosticWarn", "DiffChange" }, "fg") or 0xfab387,
	}
end

--- The active roles: the scheme's own answer, corrected by its adapter if one exists.
---@param name? string Colorscheme name; defaults to the active one
---@return theme.Roles
function M.get(name)
	local roles = M.derive()

	local adapter = M.adapter(name or vim.g.colors_name)
	if adapter and adapter.roles then
		-- An adapter refines the derived roles; it never has to supply all of them.
		roles = vim.tbl_extend("force", roles, adapter.roles(roles) or {})
	end

	return roles
end

--- The adapter for a colorscheme, or nil when it has none.
---
--- Schemes that ship variants register a name per variant ("catppuccin-macchiato",
--- "tokyonight-storm"), so the lookup walks back to the family name rather than
--- needing one adapter file per flavour.
---@param name string|nil
---@return theme.adapter|nil
function M.adapter(name)
	if not name then
		return nil
	end
	local candidate = name
	while candidate ~= "" do
		local ok, adapter = pcall(require, "theme.adapters." .. candidate)
		if ok and type(adapter) == "table" then
			return adapter
		end
		candidate = candidate:match("^(.*)%-[^-]*$") or ""
	end
	return nil
end

--- Roles as "#rrggbb" strings, which is the form nvim_set_hl takes.
---@param roles theme.Roles
---@return table
function M.to_hex(roles)
	local out = { dark = roles.dark, ramp = {} }
	for i, step in ipairs(roles.ramp) do
		out.ramp[i] = color.hex(step)
	end
	for _, key in ipairs({ "accent", "ok", "warn", "err", "info", "hint", "changed" }) do
		out[key] = color.hex(roles[key])
	end
	return out
end

return M
