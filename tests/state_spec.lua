--- Regression tests for window state under interleavings: tabs, `:only`, output that
--- arrives while the cursor is somewhere else.
local t = require("tests.harness")
local ws = require("features.workspace")
local output = require("features.lang.output")

t.describe("state", function()
	t.it("a rendering in one tab leaves other tabs alone", function()
		t.reset()
		vim.cmd.edit(t.file("a.txt", { "a" }))
		vim.cmd("vsplit " .. t.file("b.txt", { "b" }))
		local first = vim.api.nvim_get_current_tabpage()
		vim.cmd("tabnew " .. t.file("c.txt", { "c" }))
		local out = vim.api.nvim_create_buf(false, true)
		vim.b[out].lang_output = true
		local release = ws.borrow(out, { focus = false, from = vim.api.nvim_get_current_win(), lower = true })
		t.eq(2, #vim.api.nvim_tabpage_list_wins(first), "a pane in another tab was closed")
		t.eq(2, #vim.api.nvim_tabpage_list_wins(0), "the rendering did not land in this tab")
		release()
		vim.cmd("tabonly")
	end)

	t.it("releasing a created pane that became the last window gives it back", function()
		t.reset()
		vim.cmd.edit(t.file("a.txt", { "a" }))
		local scratch = vim.api.nvim_create_buf(false, true)
		local release, win = ws.borrow(scratch, { focus = true, from = vim.api.nvim_get_current_win(), lower = true })
		vim.wo[win].winfixbuf = true
		vim.cmd("only")
		release()
		t.ok(vim.api.nvim_win_get_buf(0) ~= scratch, "the rendering is still the only window")
		t.ok(pcall(vim.cmd.edit, t.file("z.txt", { "z" })), "the pane is still pinned")
	end)

	t.it("output arriving while the cursor is in a float still lands beside the source", function()
		t.reset()
		local source = t.buffer({ "one" })
		vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, {
			relative = "editor",
			row = 1,
			col = 1,
			width = 10,
			height = 2,
		})
		t.ok(pcall(output.show, { title = "probe view", lines = { "x" }, source = source, mode = "split", link = false }))
		t.eq(true, output.showing("probe view"))
		output.close("probe view")
	end)
end)
