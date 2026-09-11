--- Regression tests for the batch project check behind `<leader>iQ`, against output
--- captured from lua-language-server --check and run-clang-tidy.
local t = require("tests.harness")
local check = require("features.workspace.project_check")

t.describe("project check", function()
	t.it("reads lua-language-server's JSON report", function()
		local items = check.parse_luals([[{
			"file:///p/lua/bad.lua": [
				{ "code": "undefined-global", "message": "Undefined global `undefined_thing`.",
				  "range": { "start": { "line": 3, "character": 9 }, "end": { "line": 3, "character": 24 } },
				  "severity": 2, "source": "Lua Diagnostics." }
			]
		}]])
		t.eq(1, #items)
		t.eq({ "/p/lua/bad.lua", 4, 10, 2, "undefined-global" }, {
			items[1].filename,
			items[1].lnum,
			items[1].col,
			items[1].severity,
			items[1].code,
		})
	end)

	t.it("reads clang-tidy findings, not notes, once per header finding", function()
		local items = check.parse_tidy({
			"Running clang-tidy in 16 threads for 2 files out of 2 in compilation database ...",
			"[1/2][0.0s] /usr/bin/clang-tidy -p=. -quiet /p/b.c",
			"./h.h:1:41: warning: Undefined or garbage value returned to caller [clang-analyzer-core.uninitialized.UndefReturn]",
			"    1 | static inline int helper(void) { int x; return x; }",
			"b.c:2:22: note: Calling 'helper'",
			"[2/2][0.0s] /usr/bin/clang-tidy -p=. -quiet /p/c.c",
			"./h.h:1:41: warning: Undefined or garbage value returned to caller [clang-analyzer-core.uninitialized.UndefReturn]",
			"a.c:4:3: error: use of undeclared identifier 'x' [clang-diagnostic-error]",
		}, "/p")
		t.eq(2, #items, "notes or duplicates were kept")
		t.eq({ "/p/h.h", 1, 41, "clang-analyzer-core.uninitialized.UndefReturn" }, {
			items[1].filename,
			items[1].lnum,
			items[1].col,
			items[1].code,
		})
		t.eq("Undefined or garbage value returned to caller", items[1].message)
		t.eq(vim.diagnostic.severity.ERROR, items[2].severity)
	end)

	t.it("publishes findings for files that are not open, and clears them on save", function()
		local path = t.file("unopened.lua", { "return x" })
		check.setup()
		local files = check.apply("probe", {
			{ filename = path, lnum = 1, col = 8, severity = vim.diagnostic.severity.WARN, message = "Undefined global `x`." },
		})
		t.eq(1, files)
		local buf = vim.fn.bufnr(path)
		t.ok(buf ~= -1, "no buffer entry for the unopened file")
		t.eq(false, vim.api.nvim_buf_is_loaded(buf), "the file was loaded just to show a finding")
		t.eq(1, #vim.diagnostic.get(buf))

		t.reset()
		vim.cmd.edit(path)
		vim.cmd("silent write")
		t.eq(0, #vim.diagnostic.get(vim.api.nvim_get_current_buf(), { namespace = vim.api.nvim_create_namespace("project_check_probe") }))
	end)

	t.it("offers lua_ls in a Lua project and clang-tidy only with a compile database", function()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir .. "/.git", "p")
		vim.fn.writefile({ "{}" }, dir .. "/.luarc.json")
		vim.fn.writefile({ "return 1" }, dir .. "/a.lua")
		t.reset()
		vim.cmd.edit(dir .. "/a.lua")
		local names = vim.tbl_map(function(c)
			return c.name
		end, check.checkers(0))
		if vim.fn.executable("lua-language-server") == 1 then
			t.ok(vim.tbl_contains(names, "lua_ls"), vim.inspect(names))
		end
		t.ok(not vim.tbl_contains(names, "clang-tidy"), "clang-tidy offered without a database")
	end)
end)
