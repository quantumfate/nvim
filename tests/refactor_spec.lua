--- Regression tests for the refactoring engine.
---
--- The two that matter most are the transaction and the undo guard: one prevents a
--- half-applied refactoring, the other prevents undo from eating work you did after.
local t = require("tests.harness")
local Plan = require("features.refactor.plan")
local syntax = require("features.refactor.syntax")
local usages = require("features.refactor.usages")

---@param bufnr integer
---@param line integer 0-indexed
---@param text string
---@return lsp.TextEdit
local function insert_at(bufnr, line, text)
	return {
		range = { start = { line = line, character = 0 }, ["end"] = { line = line, character = 0 } },
		newText = text,
	}
end

t.describe("refactor", function()
	t.it("apply is all or nothing", function()
		t.reset()
		local a = t.buffer({ "one", "two" })
		vim.cmd("vsplit")
		local b = t.buffer({ "one", "two" })

		local plan = Plan.new("rollback test")
		plan:edit(a, insert_at(a, 0, "EDITED\n"))
		plan:edit(b, insert_at(b, 0, "EDITED\n"))

		-- Fail on the second buffer, after the first has already been written.
		local real, n = vim.lsp.util.apply_text_edits, 0
		vim.lsp.util.apply_text_edits = function(edits, buf, enc)
			n = n + 1
			if n == 2 then
				error("simulated failure")
			end
			return real(edits, buf, enc)
		end
		local applied = plan:apply({ verify = false })
		vim.lsp.util.apply_text_edits = real

		t.eq(false, applied, "apply should have reported failure")
		t.eq("one", vim.api.nvim_buf_get_lines(a, 0, 1, false)[1], "the first buffer was not rolled back")
		t.eq("one", vim.api.nvim_buf_get_lines(b, 0, 1, false)[1], "the second buffer was modified")
	end)

	t.it("pre-flight refuses an unmodifiable buffer", function()
		t.reset()
		local a = t.buffer({ "one" })
		vim.bo[a].modifiable = false
		local plan = Plan.new("preflight test")
		plan:edit(a, insert_at(a, 0, "EDITED\n"))
		t.eq(false, plan:apply({ verify = false }), "apply should have refused")
		vim.bo[a].modifiable = true
		t.eq("one", vim.api.nvim_buf_get_lines(a, 0, 1, false)[1], "the buffer was modified anyway")
	end)

	t.it("undo refuses when the buffer moved on", function()
		t.reset()
		local a = t.buffer({ "one" })
		local plan = Plan.new("undo guard")
		plan:edit(a, insert_at(a, 0, "REFACTORED\n"))
		plan:apply({ verify = false })

		vim.api.nvim_buf_set_lines(a, -1, -1, false, { "typed after" })
		t.eq(false, Plan.undo(), "undo should refuse over later edits")
		local lines = vim.api.nvim_buf_get_lines(a, 0, -1, false)
		t.ok(vim.tbl_contains(lines, "typed after"), "undo discarded work it should have kept")

		t.eq(true, Plan.undo({ force = true }), "forced undo should succeed")
	end)

	t.it("a plan reports what it did not check", function()
		local plan = Plan.new("coverage")
		plan:skipped_check("collision detection", "no locals query for zig")
		t.eq({ ["collision detection"] = "no locals query for zig" }, plan.unchecked)
	end)

	t.it("param_name reads past modifiers", function()
		-- Splitting the text on `[:%s]` gave "mut" for `mut x: i32`, so the still-used
		-- check searched for the wrong name and reported a parameter as unused.
		t.reset()
		local ok, parser = pcall(vim.treesitter.get_string_parser, "fn go(mut x: i32, y: &str) {}", "rust")
		if not ok or not parser then
			return -- no rust parser installed; nothing to assert against
		end
		local buf = t.buffer({ "fn go(mut x: i32, y: &str) -> i32 { x }" }, "rust")
		local tree = syntax.parsed(buf)
		if not tree then
			return
		end
		local root = tree:parse()[1]:root()
		local fn = root:named_child(0)
		local params = fn and fn:field("parameters")[1]
		if not params then
			return
		end
		local names = {}
		for _, node in ipairs(syntax.elements(params)) do
			table.insert(names, syntax.param_name(node, buf))
		end
		t.eq({ "x", "y" }, names, "a modifier was mistaken for the parameter name")
	end)

	t.it("prose matching skips English and keeps symbols", function()
		t.reset()
		local buf = t.buffer({
			"--- Computes the area of a rectangle. Call area() on it.",
			"--- See `area` and M.area for details.",
			"local function area(w, h) return w * h end",
		}, "lua")
		local hits = usages.prose(buf, "area")
		-- area() on line 1, `area` and M.area on line 2. The bare English "area" on
		-- line 1 must not match.
		t.eq(3, #hits, "wrong number of symbol-shaped matches")
		local loose = usages.prose(buf, "area", { loose = true })
		t.ok(#loose > #hits, "loose mode should match more")
	end)
end)
