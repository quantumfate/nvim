--- Guards the motion-dialect multicursor integration: the keymap layer shadows
--- the movement keys only while cursors exist, and the capture whitelist keeps
--- non-motions (`gzd`) from eating edits. The layer itself is plugin machinery;
--- these tests pin OUR contract around it.
local t = require("tests.harness")

if not pcall(require, "multicursor-nvim") then
	return
end

local mc = require("multicursor-nvim")
local feat = require("features.multicursor")

--- A word-scattered buffer so `w` has somewhere to go.
local function words_buffer()
	t.reset()
	local buf = t.buffer({ "one two three", "alpha beta", "gamma" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	return buf
end

t.describe("multicursor dialect", function()
	t.it("setup alone never opens a session", function()
		words_buffer()
		feat.setup()
		t.ok(not mc.hasCursors(), "setup must not create cursors")
	end)

	t.it("spawning shadows movement keys, and ending the session releases them", function()
		words_buffer()
		feat.setup()
		-- The gz prefix drives `addCursor(motion)`; driving the API directly
		-- exercises the same call without feeding keystrokes. The layer's
		-- mappings arm on SafeState, which headless never fires on its own —
		-- the doautocmd below is the same event a real keystroke settles into.
		mc.addCursor("w")
		vim.cmd("doautocmd SafeState")
		t.ok(mc.hasCursors(), "a motion-spawned cursor must form a session")
		local w = vim.fn.maparg("w", "n", false, true)
		t.ok(w and w.desc == "Cursor from w", "w must be shadowed by the dialect during a session")

		mc.clearCursors()
		vim.cmd("doautocmd SafeState")
		vim.wait(1000, function()
			return vim.fn.maparg("w", "n") == ""
		end, 10)
		t.eq("", vim.fn.maparg("w", "n"), "ending the session must release the movement keys")
	end)
end)
