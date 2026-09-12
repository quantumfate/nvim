--- Regression tests for Go and Python support: the output parsers, and the refactor
--- shapes the bug hunt found broken in those languages.
local t = require("tests.harness")
local go = require("features.lang.go")
local python = require("features.lang.python")
local signature = require("features.refactor.ops.signature")
local variable = require("features.refactor.ops.variable")

--- Runs `fn` with Snacks warnings captured instead of shown.
---@param fn fun()
---@return string[] warnings
local function warnings(fn)
	local seen = {}
	local real = Snacks.notify.warn
	Snacks.notify.warn = function(msg)
		table.insert(seen, msg)
	end
	local ok, err = pcall(fn)
	Snacks.notify.warn = real
	assert(ok, err)
	return seen
end

---@param lang string
---@return boolean
local function has_parser(lang)
	return (pcall(vim.treesitter.language.inspect, lang))
end

t.describe("go", function()
	t.it("asm_lines keeps this file's functions and maps their lines", function()
		local parse = go.asm_lines("/src/main.go")
		local lines, map = parse({
			"# demo",
			"main.add STEXT nosplit size=4",
			"\t0x0000 00000 (/src/main.go:5)\tTEXT\tmain.add(SB), NOSPLIT, $0-16",
			"\t0x0000 00000 (/src/main.go:5)\tFUNCDATA\t$0, gclocals(SB)",
			"\t0x0000 00000 (/src/main.go:6)\tADDQ\tBX, AX",
			"\t0x0000 48 01 d8 c3                    H...",
			"other.helper STEXT size=4",
			"\t0x0000 00000 (/src/other.go:3)\tRET",
		})
		t.eq({ "main.add:", "\tTEXT\tmain.add(SB), NOSPLIT, $0-16", "\tADDQ\tBX, AX" }, lines)
		t.eq(5, map[2])
		t.eq(6, map[3], "the instruction should map to its source line")
	end)

	t.it("escape_lines keeps this file and maps each finding", function()
		local lines, map = go.escape_lines("/src/main.go")({
			"# demo",
			"./main.go:5:6: can inline add",
			"./other.go:9:2: moved to heap: x",
			"./main.go:10:17: ~r0 escapes to heap",
		})
		t.eq(2, #lines, "another file's findings were kept")
		t.eq(5, map[1])
		t.eq(10, map[2])
	end)

	t.it("grouped parameters are refused, not half-edited", function()
		if not has_parser("go") then
			return
		end
		t.reset()
		local buf = t.buffer({ "package main", "", "func Grouped(a, b int, c string) int {", "\treturn 0", "}" }, "go")
		vim.api.nvim_win_set_cursor(0, { 3, 16 })
		local seen = warnings(function()
			signature.remove_param({ preview = false })
		end)
		t.ok(seen[1] and seen[1]:find("Grouped"), "no refusal: " .. vim.inspect(seen))
		t.eq("func Grouped(a, b int, c string) int {", vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
	end)

	t.it("a method's parameters are its parameters, not its receiver", function()
		if not has_parser("go") then
			return
		end
		t.reset()
		t.buffer({ "package main", "", "func (bx *Box) Scale(factor int) int {", "\treturn factor", "}" }, "go")
		vim.api.nvim_win_set_cursor(0, { 3, 22 })
		local seen = warnings(function()
			-- Reorder with no neighbour: the op gets as far as reading the list and stops.
			signature.reorder_param({ direction = "next", preview = false })
		end)
		t.ok(
			seen[1] and seen[1]:find("neighbouring"),
			"cursor on `factor` was not seen as a parameter: " .. vim.inspect(seen)
		)
	end)
end)

t.describe("python", function()
	t.it("dis_lines maps bytecode rows to source lines", function()
		local _, map = python.dis_lines({
			"  0           RESUME                   0",
			"",
			"  4           LOAD_NAME                1 (print)",
			"              PUSH_NULL",
			'Disassembly of <code object add at 0x7f, file "p.py", line 1>:',
			"  2           LOAD_FAST                0 (a)",
		})
		t.eq(nil, map[1], "line 0 is the module prologue, not a source line")
		t.eq(4, map[3])
		t.eq(4, map[4], "continuation rows belong to the line above")
		t.eq(nil, map[5])
		t.eq(2, map[6])
	end)

	t.it("the project's .venv wins over PATH", function()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir .. "/.venv/bin", "p")
		vim.fn.writefile({}, dir .. "/pyproject.toml")
		vim.fn.writefile({}, dir .. "/.venv/bin/python")
		vim.fn.writefile({ "print(1)" }, dir .. "/app.py")
		t.reset()
		vim.cmd.edit(dir .. "/app.py")
		local active = vim.env.VIRTUAL_ENV
		vim.env.VIRTUAL_ENV = nil
		local interpreter = python.interpreter(0)
		vim.env.VIRTUAL_ENV = active
		t.eq(vim.fs.joinpath(vim.uv.fs_realpath(dir) or dir, ".venv", "bin", "python"), interpreter)
	end)

	t.it("a spec with a space is refused", function()
		if not has_parser("python") then
			return
		end
		t.reset()
		local buf = t.buffer({ "def area(w, h):", "    return w * h" }, "python")
		vim.api.nvim_win_set_cursor(0, { 1, 4 })
		local seen = warnings(function()
			signature.add_param({ spec = "depth int", preview = false })
		end)
		t.ok(seen[1] and seen[1]:find("name:type"), "no warning: " .. vim.inspect(seen))
		t.eq("def area(w, h):", vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
	end)
end)

t.describe("inline", function()
	t.it("leaves field names alone", function()
		t.reset()
		local buf = t.buffer({ "local w = 3", "local p = { w = 1 }", "print(p.w + w)" }, "lua")
		vim.api.nvim_win_set_cursor(0, { 1, 6 })
		variable.inline({ preview = false })
		t.eq({ "local p = { w = 1 }", "print(p.w + 3)" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
	end)

	t.it("parenthesises a compound value", function()
		t.reset()
		local buf = t.buffer({ "local a, b = 1, 2", "local s = a + b", "print(s * 2)" }, "lua")
		vim.api.nvim_win_set_cursor(0, { 2, 6 })
		variable.inline({ preview = false })
		t.eq("print((a + b) * 2)", vim.api.nvim_buf_get_lines(buf, -2, -1, false)[1])
	end)
end)
