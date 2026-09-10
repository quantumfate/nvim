--- Regression tests for the language actions and the crash reader.
local t = require("tests.harness")
local output = require("features.lang.output")
local lang = require("features.lang")
local imports = require("features.refactor.imports")
local jobs = require("features.lang.jobs")
local kernel = require("features.crash.kernel")

t.describe("lang", function()
	t.it("strip_asm maps output rows to source lines", function()
		local kept, map = output.strip_asm({
			'\t.file\t"main.c"',
			"\t.globl\tmain",
			"\t.loc\t1 11 0",
			"\tpush\trbp",
			"\tmov\trbp, rsp",
			"\t.loc\t1 16 0",
			"\tcall\tclassify",
		})
		t.eq({ "\t.globl\tmain", "\tpush\trbp", "\tmov\trbp, rsp", "\tcall\tclassify" }, kept)
		-- `.loc` is consumed, not shown, so the map indexes the lines that survived.
		t.eq(11, map[2], "the first instruction should map to line 11")
		t.eq(11, map[3])
		t.eq(16, map[4], "the call should map to line 16")
	end)

	t.it("strip_asm drops debug sections", function()
		-- `-g` is added for the `.loc` markers, and brings DWARF string tables with it.
		local kept = output.strip_asm({
			"\tmov\teax, 1",
			'\t.section\t.debug_str,"MS",@progbits,1',
			'\t.asciz\t"clang version 21"',
			"\t.long\t42",
			'\t.section\t.text,"ax",@progbits',
			"\tret",
		})
		for _, line in ipairs(kept) do
			t.ok(not line:find("debug"), "a debug line survived: " .. line)
			t.ok(not line:find("asciz"), "debug content survived: " .. line)
		end
		t.ok(vim.tbl_contains(kept, "\tret"), "code after the debug section was dropped")
	end)

	t.it("only_module keeps this file's functions", function()
		local filter = output.only_module("main.")
		local kept = filter({
			"define i32 @std.other() {",
			"  ret i32 0",
			"}",
			"define i32 @main.area(i32 %0) {",
			"  ret i32 %0",
			"}",
			"!7 = !DILocation(line: 12, column: 1)",
		})
		local text = table.concat(kept, "\n")
		t.ok(text:find("main.area", 1, true), "the module's own function was dropped")
		t.ok(not text:find("std.other", 1, true), "another module's function was kept")
		t.ok(text:find("DILocation", 1, true), "metadata the cursor link needs was dropped")
	end)

	t.it("titles are declared for the toggle to find", function()
		-- The toggle asks "is this view already showing" by title, so a capability with
		-- no title silently stops toggling.
		for _, ft in ipairs({ "c", "zig", "lua" }) do
			t.ok(lang.title(ft, "assembly"), ft .. " has no title for assembly")
		end
	end)

	t.it("jobs report while they run", function()
		local finish = jobs.start("probe", "sleep")
		t.eq(true, jobs.active())
		t.ok(jobs.status():find("probe", 1, true), "the status does not name the job")
		finish()
		t.eq(false, jobs.active())
		t.eq("", jobs.status())
	end)

	t.it("a view closed by hand is noticed", function()
		-- The bug behind "the binding stops working": a window closed with `:q` left the
		-- record saying it was open, so the next press closed nothing.
		t.reset()
		output.setup()
		local source = t.buffer({ "one" })
		output.show({ title = "probe view", lines = { "x" }, source = source, mode = "split", link = false })
		t.eq(true, output.showing("probe view"))

		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.b[vim.api.nvim_win_get_buf(win)].lang_output then
				pcall(vim.api.nvim_win_close, win, true)
			end
		end
		t.eq(false, output.showing("probe view"), "the closed view still reads as showing")
	end)

	t.it("closing a view by hand does not block reopening it", function()
		-- The symptom was "the key stops working": a leftover pane plus a stale record
		-- meant the next press toggled off something that was not there.
		t.reset()
		output.setup()
		local source = t.buffer({ "one" })
		local opts = { title = "probe view", lines = { "x" }, source = source, mode = "split", link = false }

		output.show(opts)
		t.eq(true, output.showing("probe view"))
		output.close("probe view")
		t.eq(false, output.showing("probe view"))

		output.show(opts)
		t.eq(true, output.showing("probe view"), "reopening after a close was refused")
	end)

	t.it("a second run of the same view is refused", function()
		-- Two presses during a nine-second build started two compiles.
		local finish = jobs.start("busy view", "sleep")
		t.eq(true, jobs.running("busy view"))
		t.eq(false, jobs.running("other view"))
		finish()
		t.eq(false, jobs.running("busy view"))
	end)

	t.it("lua import paths come from the lua/ directory", function()
		t.reset()
		local buf = t.buffer({ "local M = {}" }, "lua")
		vim.api.nvim_buf_set_name(buf, "/tmp/proj/lua/app/init.lua")
		local statement = imports.needed(buf, "/tmp/proj/lua/features/thing.lua", "thing")
		t.eq('local thing = require("features.thing")', statement)
	end)

	t.it("js import paths are relative", function()
		t.reset()
		local buf = t.buffer({ "" }, "typescript")
		vim.api.nvim_buf_set_name(buf, "/tmp/proj/src/app.ts")
		t.eq('import { h } from "./util/h";', imports.needed(buf, "/tmp/proj/src/util/h.ts", "h"))
		t.eq('import { x } from "../lib/x";', imports.needed(buf, "/tmp/proj/lib/x.ts", "x"))
	end)

	t.it("kernel frames parse symbol and offset", function()
		local frames = kernel.frames({
			"[  142.331935] RIP: 0010:my_probe+0x47/0x120",
			"[  142.331952]  other_fn+0x9/0x20",
			"[  142.331960]  </TASK>",
		})
		t.eq(2, #frames, "wrong number of frames")
		t.eq("my_probe", frames[1].symbol)
		t.eq(0x47, frames[1].offset)
		t.eq("other_fn", frames[2].symbol)
	end)
end)
