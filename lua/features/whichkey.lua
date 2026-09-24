--- which-key popup placement: a vertical rail that hugs the cursor's half.
---
--- The spec's `win` table pins the geometry (bottom-anchored rail, `row =
--- math.huge` — the same anchor trick the upstream default uses, so the height
--- arithmetic stays inside the editor grid). Which edge it hugs is the moving
--- part: `Config.win` is read fresh on every popup show (`view.show` →
--- `Win.defaults(Config.win)`), and `col` speaks the same `Layout.dim` language
--- (`0` = left edge, `math.huge` = right edge). There is no supported per-show
--- hook for `col`, so this wraps `view.show` and rewrites it before each show —
--- the same seam `features/mini.lua` uses for `mini.pairs.open`.
---
--- Rail width is narrow on purpose: it is a reference strip next to the pane
--- being edited, not a second panel competing with the left sidebar and the
--- dock. It never steals focus (`focusable = false` upstream), so the cursor
--- keeps moving while it is up.
---@class features.whichkey
local M = {}

--- Which editor edge the rail hugs for a cursor at `cursor_col`.
--- Left rail for the left half of the screen, right rail for the right half —
--- the box follows the pane the cursor is working in. (Flip the comparison to
--- park the rail on the opposite side, away from the text being edited.)
---@param cursor_col integer 1-based screen column of the cursor
---@param columns integer editor width in cells
---@return number col 0 (left edge) or math.huge (right edge)
function M.rail_col(cursor_col, columns)
	return cursor_col * 2 <= columns and 0 or math.huge
end

--- The cursor's screen column, computed from the current window's offset plus
--- the cursor's display column inside it. (`screencol()` tracks the same thing
--- on a drawn screen, but reports stale values in headless sessions.)
---@return integer
local function cursor_screen_col()
	local win_col = vim.fn.win_screenpos(0)[2]
	return win_col + vim.fn.virtcol(".") - 1
end

--- Re-derives the rail's side before every popup show.
---
--- The interception point is `which-key.win.defaults`: every popup show path
--- (state → view.update → view.M.show) resolves `Win.defaults(Config.win)`
--- through this module field at call time, and the returned table is what
--- view.lua then feeds through `Layout.dim` — so a rewritten `col` is honored
--- whether the popup opens fresh or re-configures an open one. `view.show`
--- itself is not the seam: its internal callers reach the module-local
--- function, bypassing any field wrap.
function M.setup()
	local win = require("which-key.win")
	local defaults = win.defaults
	win.defaults = function(opts)
		-- Deepcopy keeps Config.win itself pristine; the rail side is derived
		-- fresh at the moment of the call, not cached into the config.
		opts = opts and vim.deepcopy(opts) or {}
		opts.col = M.rail_col(cursor_screen_col(), vim.o.columns)
		return defaults(opts)
	end
end

return M
