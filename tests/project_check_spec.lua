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
			{
				filename = path,
				lnum = 1,
				col = 8,
				severity = vim.diagnostic.severity.WARN,
				message = "Undefined global `x`.",
			},
		})
		t.eq(1, files)
		local buf = vim.fn.bufnr(path)
		t.ok(buf ~= -1, "no buffer entry for the unopened file")
		t.eq(false, vim.api.nvim_buf_is_loaded(buf), "the file was loaded just to show a finding")
		t.eq(1, #vim.diagnostic.get(buf))

		t.reset()
		vim.cmd.edit(path)
		vim.cmd("silent write")
		t.eq(
			0,
			#vim.diagnostic.get(
				vim.api.nvim_get_current_buf(),
				{ namespace = vim.api.nvim_create_namespace("project_check_probe") }
			)
		)
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
		t.ok(not vim.tbl_contains(names, "clippy"), "clippy offered without Cargo.toml")
		t.ok(not vim.tbl_contains(names, "go vet"), "go vet offered without go.mod")
		t.ok(not vim.tbl_contains(names, "tsc"), "tsc offered without tsconfig.json")
	end)

	t.it("offers clippy, go vet and tsc only where their project marker is", function()
		local cases = {
			{ marker = "Cargo.toml", file = "src/main.rs", tool = "cargo", name = "clippy" },
			{ marker = "go.mod", file = "sub/x.go", tool = "go", name = "go vet" },
			{ marker = "tsconfig.json", file = "src/a.ts", tool = "tsc", name = "tsc" },
		}
		for _, case in ipairs(cases) do
			local dir = vim.fn.tempname()
			vim.fn.mkdir(dir .. "/.git", "p")
			vim.fn.mkdir(vim.fs.dirname(dir .. "/" .. case.file), "p")
			vim.fn.writefile({ "" }, dir .. "/" .. case.marker)
			vim.fn.writefile({ "" }, dir .. "/" .. case.file)
			t.reset()
			vim.cmd.edit(dir .. "/" .. case.file)
			local checkers = check.checkers(0)
			local names = vim.tbl_map(function(c)
				return c.name
			end, checkers)
			local others = vim.tbl_filter(function(c)
				return c.name ~= case.name
			end, cases)
			for _, other in ipairs(others) do
				t.ok(not vim.tbl_contains(names, other.name), case.marker .. " offered " .. other.name)
			end
			if
				vim.fn.executable(case.tool) == 1
				and not (case.name == "go vet" and vim.fn.executable("golangci-lint") == 1)
			then
				local found = vim.iter(checkers):find(function(c)
					return c.name == case.name
				end)
				t.ok(found, case.marker .. ": " .. vim.inspect(names))
				t.eq(vim.fs.normalize(dir), found.cwd, "checker runs from the marker's directory")
			end
		end
	end)

	t.it("reads clippy's JSON messages once per finding, at the primary span", function()
		-- Captured from a crate with a type error; `rendered`, `children` and span text trimmed.
		local stdout = table.concat({
			[[{"reason":"compiler-message","manifest_path":"/p/Cargo.toml","target":{"kind":["bin"]},"message":{"rendered":"","$message_type":"diagnostic","children":[],"level":"error","message":"mismatched types","spans":[{"byte_end":36,"byte_start":30,"column_end":24,"column_start":18,"expansion":null,"file_name":"src/other.rs","is_primary":true,"label":"expected `i32`, found `&str`","line_end":2,"line_start":2,"suggested_replacement":null,"suggestion_applicability":null,"text":[]},{"byte_end":27,"byte_start":24,"column_end":15,"column_start":12,"expansion":null,"file_name":"src/other.rs","is_primary":false,"label":"expected due to this","line_end":2,"line_start":2,"suggested_replacement":null,"suggestion_applicability":null,"text":[]}],"code":{"code":"E0308","explanation":"Expected type did not match the received type."}}}]],
			[[{"reason":"compiler-message","manifest_path":"/p/Cargo.toml","target":{"kind":["bin"]},"message":{"rendered":"","$message_type":"diagnostic","children":[],"level":"error","message":"mismatched types","spans":[{"byte_end":36,"byte_start":30,"column_end":24,"column_start":18,"expansion":null,"file_name":"src/other.rs","is_primary":true,"label":"expected `i32`, found `&str`","line_end":2,"line_start":2,"suggested_replacement":null,"suggestion_applicability":null,"text":[]}],"code":{"code":"E0308","explanation":null}}}]],
			[[{"reason":"compiler-message","manifest_path":"/p/Cargo.toml","target":{"kind":["bin"]},"message":{"rendered":"","$message_type":"diagnostic","children":[],"level":"failure-note","message":"For more information about this error, try `rustc --explain E0308`.","spans":[],"code":null}}]],
			[[{"reason":"compiler-message","manifest_path":"/p/Cargo.toml","target":{"kind":["bin"]},"message":{"rendered":"","$message_type":"diagnostic","children":[],"level":"warning","message":"length comparison to zero","spans":[{"byte_end":69,"byte_start":57,"column_end":20,"column_start":8,"expansion":null,"file_name":"src/main.rs","is_primary":true,"label":null,"line_end":4,"line_start":4,"suggested_replacement":null,"suggestion_applicability":null,"text":[]}],"code":{"code":"clippy::len_zero","explanation":null}}}]],
			[[{"reason":"build-finished","success":false}]],
		}, "\n")
		local items, failure =
			check.parse_clippy(stdout, 'error: could not compile `probe` (bin "probe") due to 1 previous error', "/p")
		t.eq(nil, failure)
		t.eq(2, #items, vim.inspect(items))
		t.eq({ "/p/src/other.rs", 2, 18, vim.diagnostic.severity.ERROR, "mismatched types", "E0308" }, {
			items[1].filename,
			items[1].lnum,
			items[1].col,
			items[1].severity,
			items[1].message,
			items[1].code,
		})
		t.eq({ "/p/src/main.rs", vim.diagnostic.severity.WARN, "clippy::len_zero" }, {
			items[2].filename,
			items[2].severity,
			items[2].code,
		})
	end)

	t.it("reports a clippy run that never checked as a failure", function()
		-- A panicking build script: the build fails with no compiler error to show.
		local _, failure = check.parse_clippy(
			[[{"reason":"compiler-artifact","target":{"kind":["custom-build"]}}]]
				.. "\n"
				.. [[{"reason":"build-finished","success":false}]],
			"   Compiling bs v0.1.0 (/p)\nerror: failed to run custom build command for `bs v0.1.0 (/p)`\n\nCaused by:\n  thread 'main' panicked at build.rs:1:12:\n  boom",
			"/p"
		)
		t.eq("error: failed to run custom build command for `bs v0.1.0 (/p)`", failure)
		local _, missing =
			check.parse_clippy("", "error: could not find `Cargo.toml` in `/p` or any parent directory", "/p")
		t.eq("error: could not find `Cargo.toml` in `/p` or any parent directory", missing)
		local clean, none = check.parse_clippy([[{"reason":"build-finished","success":true}]], "", "/p")
		t.eq({ 0, nil }, { #clean, none })
	end)

	t.it("reads go vet findings and type errors, not package headers", function()
		local items = check.parse_govet({
			"# probe/sub",
			"# [probe/sub]",
			'sub/sub.go:6:14: fmt.Printf format %d has arg "str" of wrong type string',
			"vet: ./main.go:3:15: undefined: undefined_x",
		}, "/m")
		t.eq(2, #items)
		t.eq({ "/m/sub/sub.go", 6, 14 }, { items[1].filename, items[1].lnum, items[1].col })
		t.eq('fmt.Printf format %d has arg "str" of wrong type string', items[1].message)
		t.eq({ "/m/main.go", "undefined: undefined_x" }, { items[2].filename, items[2].message })
	end)

	t.it("reads golangci-lint's JSON report and rejects anything else", function()
		-- golangci-lint is not installed here; shape from its documented v1 JSON output.
		local items = check.parse_golangci(
			[[{"Issues":[{"FromLinter":"govet","Text":"printf: fmt.Printf format %d has arg \"str\" of wrong type string","Severity":"","SourceLines":["\tfmt.Printf(\"%d\\n\", \"str\")"],"Replacement":null,"Pos":{"Filename":"sub/sub.go","Offset":45,"Line":6,"Column":14},"ExpectNoLint":false,"ExpectedNoLintLinter":""},{"FromLinter":"typecheck","Text":"undefined: x","Severity":"error","SourceLines":[],"Replacement":null,"Pos":{"Filename":"main.go","Offset":0,"Line":3,"Column":0},"ExpectNoLint":false,"ExpectedNoLintLinter":""}],"Report":{"Linters":[{"Name":"govet","Enabled":true}]}}]],
			"/m"
		)
		assert(items)
		t.eq(2, #items)
		t.eq({ "/m/sub/sub.go", 6, 14, "govet" }, { items[1].filename, items[1].lnum, items[1].col, items[1].code })
		t.eq({ 1, vim.diagnostic.severity.ERROR }, { items[2].col, items[2].severity })
		t.eq(0, #check.parse_golangci([[{"Issues":null,"Report":{}}]], "/m"))
		t.eq(nil, check.parse_golangci("Error: unknown flag: --out-format", "/m"))
	end)

	t.it("reads tsc diagnostics, including ones in tsconfig.json", function()
		local items = check.parse_tsc({
			"src/a.ts(1,14): error TS2322: Type 'string' is not assignable to type 'number'.",
			"tsconfig.json(1,24): error TS5023: Unknown compiler option 'bogus'.",
			"error TS18003: No inputs were found in config file '/t/tsconfig.json'.",
		}, "/t")
		t.eq(2, #items)
		t.eq({ "/t/src/a.ts", 1, 14, vim.diagnostic.severity.ERROR, "TS2322" }, {
			items[1].filename,
			items[1].lnum,
			items[1].col,
			items[1].severity,
			items[1].code,
		})
		t.eq("Type 'string' is not assignable to type 'number'.", items[1].message)
		t.eq("/t/tsconfig.json", items[2].filename)
	end)

	t.it("serialises findings as one JSON object per line, sorted by position", function()
		local headless = require("features.workspace.headless")
		local records = {
			headless.record({
				filename = "/p/b.lua",
				lnum = 2,
				col = 3,
				severity = vim.diagnostic.severity.WARN,
				message = "second",
				code = "undefined-global",
			}, "lua_ls"),
			headless.record({
				filename = "/p/a.c",
				lnum = 9,
				col = 1,
				severity = vim.diagnostic.severity.ERROR,
				message = "first",
			}, "clang-tidy"),
		}
		local lines = vim.split(vim.trim(headless.encode(records)), "\n", { plain = true })
		t.eq(2, #lines)
		t.eq({
			file = "/p/a.c",
			lnum = 9,
			col = 1,
			severity = "error",
			source = "clang-tidy",
			message = "first",
		}, vim.json.decode(lines[1]), "the error should sort first and carry no code key")
		t.eq({
			file = "/p/b.lua",
			lnum = 2,
			col = 3,
			severity = "warning",
			source = "lua_ls",
			message = "second",
			code = "undefined-global",
		}, vim.json.decode(lines[2]))
		t.eq("", headless.encode({}), "a clean run should print nothing at all")
	end)

	t.it("exits non-zero only for errors, and a checker that did not run is an error", function()
		local headless = require("features.workspace.headless")
		local warning = headless.record({
			filename = "/p/a.lua",
			lnum = 1,
			col = 1,
			severity = vim.diagnostic.severity.WARN,
			message = "meh",
		}, "lua_ls")
		local error_ = headless.record({
			filename = "/p/a.c",
			lnum = 1,
			col = 1,
			severity = vim.diagnostic.severity.ERROR,
			message = "boom",
		}, "clang-tidy")
		t.eq(0, headless.exit_code({}))
		t.eq(0, headless.exit_code({ warning }))
		t.eq(1, headless.exit_code({ warning, error_ }))

		local failure = headless.failure("clippy", "no cargo", "/p")
		t.eq("error", failure.severity, "a tool that never ran must not look clean")
		t.eq(1, headless.exit_code({ failure }))
	end)
end)
