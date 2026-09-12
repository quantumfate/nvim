--- Regression tests for the window layout.
---
--- Every case here is a bug that shipped: panes multiplying, output landing on the
--- wrong side, a borrow that lost a file, a layout key that only went one way.
local t = require("tests.harness")
local ws = require("features.workspace")

---@return integer
local function content_panes()
	local n = 0
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.api.nvim_win_get_config(win).relative == "" then
			if vim.bo[buf].buftype == "" or vim.b[buf].lang_output then
				n = n + 1
			end
		end
	end
	return n
end

t.describe("workspace", function()
	t.it("layout is idempotent", function()
		t.reset()
		vim.cmd.edit(t.file("a.txt", { "one" }))
		ws.layout()
		local first = content_panes()
		ws.layout()
		ws.layout()
		t.eq(first, content_panes(), "running layout three times changed the pane count")
	end)

	t.it("keeps at most two content panes", function()
		t.reset()
		vim.cmd.edit(t.file("a.txt", { "one" }))
		vim.cmd("vsplit")
		vim.cmd("vsplit")
		vim.cmd("vsplit")
		t.ok(content_panes() > 2, "setup should have made more than two panes")
		ws.enforce_two()
		t.eq(2, content_panes(), "extra panes were not closed")
	end)

	t.it("counts a rendering as a content pane", function()
		-- The bug: enforce_two counted editors only, so `file | file | asm` read as two
		-- and three panes shared the width.
		t.reset()
		vim.cmd.edit(t.file("a.txt", { "one" }))
		vim.cmd("vsplit")
		local out = vim.api.nvim_create_buf(false, true)
		vim.b[out].lang_output = true
		vim.cmd("vsplit")
		vim.api.nvim_win_set_buf(0, out)
		t.eq(3, content_panes(), "setup should have three content panes")
		ws.enforce_two()
		t.eq(2, content_panes(), "a rendering was not counted against the limit")
	end)

	t.it("toggle_layout goes both ways", function()
		t.reset()
		vim.cmd.edit(t.file("a.txt", { "one" }))
		ws.toggle_layout()
		local expanded = content_panes()
		t.ok(expanded > 1, "expanding produced no second pane")
		ws.toggle_layout()
		t.eq(1, content_panes(), "collapsing did not return to one pane")
		ws.toggle_layout()
		t.eq(expanded, content_panes(), "expanding again gave a different shape")
	end)

	t.it("lower() puts a rendering in the right pane", function()
		t.reset()
		vim.cmd.edit(t.file("left.txt", { "left" }))
		ws.layout()
		local wins = vim.api.nvim_list_wins()
		local left = wins[1]
		vim.api.nvim_set_current_win(left)
		local target = ws.lower(left)
		assert(target)
		t.ok(target ~= left, "lower returned the pane it was called from")
		local left_col = vim.api.nvim_win_get_position(left)[2]
		local target_col = vim.api.nvim_win_get_position(target)[2]
		t.ok(target_col > left_col, "the target was not to the right of the source")
	end)

	t.it("lower() moves the source left when it is already on the right", function()
		-- The flipped-panes bug: standing in the right pane put the assembly on the
		-- left, where the eye expects the source.
		t.reset()
		local a = t.file("a.txt", { "aaa" })
		local b = t.file("b.txt", { "bbb" })
		vim.cmd.edit(a)
		vim.cmd("vsplit " .. b)
		local wins = vim.api.nvim_list_wins()
		table.sort(wins, function(x, y)
			return vim.api.nvim_win_get_position(x)[2] < vim.api.nvim_win_get_position(y)[2]
		end)
		local left, right = wins[1], wins[2]
		local source_buf = vim.api.nvim_win_get_buf(right)

		vim.api.nvim_set_current_win(right)
		local target, source_now = ws.lower(right)

		t.eq(right, target, "the target should still be the right pane")
		t.eq(left, source_now, "the source should have moved to the left pane")
		t.eq(source_buf, vim.api.nvim_win_get_buf(left), "the left pane is not showing the source")
	end)

	t.it("borrow restores the buffer it displaced", function()
		t.reset()
		local a = t.file("a.txt", { "aaa" })
		local b = t.file("b.txt", { "bbb" })
		vim.cmd.edit(a)
		vim.cmd("vsplit " .. b)
		local wins = vim.api.nvim_list_wins()
		table.sort(wins, function(x, y)
			return vim.api.nvim_win_get_position(x)[2] < vim.api.nvim_win_get_position(y)[2]
		end)
		local left, right = wins[1], wins[2]
		local displaced = vim.api.nvim_win_get_buf(right)

		vim.api.nvim_set_current_win(left)
		local scratch = vim.api.nvim_create_buf(false, true)
		vim.b[scratch].lang_output = true
		local release = ws.borrow(scratch, { focus = false, from = left, lower = true })

		t.ok(vim.api.nvim_win_get_buf(right) == scratch, "the borrow did not take the pane")
		release()
		t.eq(displaced, vim.api.nvim_win_get_buf(right), "the displaced buffer was not restored")
	end)

	t.it("a bottom split is not a content pane", function()
		-- Counting one meant pressing Enter on a crash frame closed the report, the
		-- outline and everything else to satisfy a limit meant for side-by-side panes.
		t.reset()
		vim.cmd.edit(t.file("a.txt", { "one" }))
		vim.cmd("vsplit")
		vim.cmd("botright split")
		local bottom = vim.api.nvim_get_current_win()
		vim.b[vim.api.nvim_win_get_buf(bottom)].lang_output = true
		local before = #vim.api.nvim_list_wins()
		ws.enforce_two()
		t.eq(before, #vim.api.nvim_list_wins(), "a bottom split was closed")
	end)

	t.it("collapse spares panes the user opened", function()
		-- Tearing down a split someone made on purpose, then re-opening a different one,
		-- is what made this key feel random.
		t.reset()
		vim.cmd.edit(t.file("a.txt", { "one" }))
		vim.cmd("vsplit")
		local before = #vim.api.nvim_list_wins()
		ws.collapse()
		t.eq(before, #vim.api.nvim_list_wins(), "a user-made pane was closed")
	end)

	t.it("expanded() is derived, not remembered", function()
		t.reset()
		vim.cmd.edit(t.file("a.txt", { "one" }))
		t.eq(false, ws.expanded(), "a single pane should not read as expanded")
		vim.cmd("vsplit")
		t.eq(true, ws.expanded(), "two panes should read as expanded")
		vim.cmd("only")
		t.eq(false, ws.expanded(), "closing the pane by hand was not noticed")
	end)

	t.it("a borrow that created the pane closes it again", function()
		-- Restoring the buffer it was seeded with left a second copy of the file you
		-- were already reading, in a pane you never asked for — and the leftover pane
		-- then confused the toggle into refusing to reopen.
		t.reset()
		vim.cmd.edit(t.file("a.txt", { "one" }))
		local before = #vim.api.nvim_list_wins()

		local source = vim.api.nvim_get_current_win()
		local scratch = vim.api.nvim_create_buf(false, true)
		vim.b[scratch].lang_output = true
		local release = ws.borrow(scratch, { focus = false, from = source, lower = true })
		t.eq(before + 1, #vim.api.nvim_list_wins(), "the borrow did not create a pane")

		release()
		t.eq(before, #vim.api.nvim_list_wins(), "the created pane was left behind")
	end)

	t.it("a borrow into an existing pane restores rather than closes", function()
		t.reset()
		local a = t.file("a.txt", { "aaa" })
		local b = t.file("b.txt", { "bbb" })
		vim.cmd.edit(a)
		vim.cmd("vsplit " .. b)
		local before = #vim.api.nvim_list_wins()

		local source = vim.api.nvim_get_current_win()
		local scratch = vim.api.nvim_create_buf(false, true)
		vim.b[scratch].lang_output = true
		local release = ws.borrow(scratch, { focus = false, from = source, lower = true })
		release()

		t.eq(before, #vim.api.nvim_list_wins(), "a pane that already existed was closed")
	end)

	t.it("a borrowed pane can be given back despite winfixbuf", function()
		-- winfixbuf pins the pane so nothing wanders into it; release has to lift it,
		-- which it did not, and every restore failed with E1513.
		t.reset()
		vim.cmd.edit(t.file("a.txt", { "aaa" }))
		vim.cmd("vsplit")
		local wins = vim.api.nvim_list_wins()
		local left, right = wins[2], wins[1]
		local displaced = vim.api.nvim_win_get_buf(right)

		vim.api.nvim_set_current_win(left)
		local scratch = vim.api.nvim_create_buf(false, true)
		local release = ws.borrow(scratch, { focus = false, from = left })
		vim.wo[right].winfixbuf = true
		release()
		t.eq(displaced, vim.api.nvim_win_get_buf(right), "winfixbuf blocked the restore")
	end)
end)
