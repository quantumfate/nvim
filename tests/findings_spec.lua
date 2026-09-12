--- Regression tests for bug-hunt findings that could only be seen with a language
--- server running. Each test here drives the part that does not need one.
local t = require("tests.harness")
local Plan = require("features.refactor.plan")
local syntax = require("features.refactor.syntax")

---@param lang string
---@return boolean
local function has_parser(lang)
	return (pcall(vim.treesitter.language.inspect, lang))
end

--- Runs `fn` with warnings captured.
---@param fn fun()
---@return string[]
local function warnings(fn)
	local seen, real = {}, Snacks.notify.warn
	Snacks.notify.warn = function(msg)
		table.insert(seen, msg)
	end
	pcall(fn)
	Snacks.notify.warn = real
	return seen
end

--- Runs an op and returns the plan it would have applied, without applying it.
---@param fn fun()
---@return refactor.Plan?
local function planned(fn)
	local real, got = Plan.finish, nil
	Plan.finish = function(plan)
		Plan.done()
		got = plan
	end
	local notify = Snacks.notify.warn
	Snacks.notify.warn = function() end
	pcall(fn)
	vim.wait(3000, function()
		return got ~= nil
	end, 20)
	Plan.finish, Snacks.notify.warn = real, notify
	return got
end

t.describe("findings", function()
	t.it("extract at Go package level writes var, not :=", function()
		if not has_parser("go") then
			return
		end
		t.reset()
		local buf = t.buffer({ "package main", "var total = 10 + 5" }, "go")
		vim.fn.setpos("'<", { 0, 2, 13, 0 })
		vim.fn.setpos("'>", { 0, 2, 18, 0 })
		require("features.refactor.ops.variable").extract({ name = "v", preview = false })
		t.eq({ "package main", "var v = 10 + 5", "var total = v" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
	end)

	t.it("a Rust attribute travels with the item's doc comment", function()
		if not has_parser("rust") then
			return
		end
		t.reset()
		local buf = t.buffer({ "/// Unused helper.", "#[allow(dead_code)]", "fn orphan() {}" }, "rust")
		t.eq(0, syntax.doc_start(buf, 2), "the attribute stopped the doc comment search")
	end)

	t.it("safe delete takes Python decorators with the function", function()
		if not has_parser("python") then
			return
		end
		t.reset()
		t.buffer({ "import functools", "", "@functools.cache", "def orphan():", "    return 42" }, "python")
		vim.api.nvim_win_set_cursor(0, { 5, 4 })
		local plan = planned(function()
			require("features.refactor.ops.safe_delete").run({ preview = false })
		end)
		t.ok(plan, "no plan was produced")
		assert(plan and plan.edits)
		local _, edits = next(plan.edits)
		assert(edits and edits[1])
		t.eq(2, edits[1].range.start.line, "the decorator line was left behind")
	end)

	t.it("move refuses to pull a method out of its class", function()
		if not has_parser("python") then
			return
		end
		t.reset()
		t.buffer({ "class Shape:", "    def double(self):", "        return 2" }, "python")
		vim.api.nvim_win_set_cursor(0, { 3, 8 })
		local seen = warnings(function()
			require("features.refactor.ops.move").run({ path = vim.fn.tempname() .. ".py", preview = false })
		end)
		t.ok(seen[1] and seen[1]:find("method"), "not refused: " .. vim.inspect(seen))
	end)

	t.it("inline refuses a tuple binding", function()
		if not has_parser("python") then
			return
		end
		t.reset()
		local buf = t.buffer({ "a, b = 1, 2", "print(a + b)" }, "python")
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		local seen = warnings(function()
			require("features.refactor.ops.variable").inline({ preview = false })
		end)
		t.ok(seen[1] and seen[1]:find("several"), "not refused: " .. vim.inspect(seen))
		t.eq("a, b = 1, 2", vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
	end)

	t.it("a required parameter after a default is a conflict", function()
		if not has_parser("python") then
			return
		end
		t.reset()
		t.buffer({ "def kw(alpha, beta=2):", "    return alpha + beta" }, "python")
		vim.api.nvim_win_set_cursor(0, { 1, 4 })
		local plan = planned(function()
			require("features.refactor.ops.signature").add_param({ spec = "gamma", preview = false })
		end)
		t.ok(plan, "no plan was produced")
		assert(plan and plan.conflicts)
		local texts = vim.tbl_map(function(c)
			return c.text
		end, plan.conflicts)
		t.ok(table.concat(texts, "\n"):find("required parameter"), vim.inspect(texts))
	end)

	t.it("moving into a new Go file writes its package clause", function()
		if not has_parser("go") then
			return
		end
		t.reset()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		vim.fn.writefile({ "package shapes", "", "func orphan() int {", "\treturn 42", "}" }, dir .. "/a.go")
		vim.cmd.edit(dir .. "/a.go")
		vim.api.nvim_win_set_cursor(0, { 4, 1 })
		local plan = planned(function()
			require("features.refactor.ops.move").run({ path = dir .. "/b.go", preview = false })
		end)
		t.ok(plan, "no plan was produced")
		assert(plan and plan.edits)
		local found = false
		for buf, edits in pairs(plan.edits) do
			if vim.api.nvim_buf_get_name(buf):match("b%.go$") then
				found = edits[1].newText:match("^package shapes\n") ~= nil
			end
		end
		t.ok(found, "the new file has no package clause")
	end)

	t.it("the dock has a project-wide diagnostics view", function()
		local view = require("features.workspace").dock().views.project
		t.ok(view and type(view.open) == "function" and view.ft == "trouble")
	end)

	t.it("splitting beside a rendering keeps its source on screen", function()
		t.reset()
		local ws = require("features.workspace")
		local output = require("features.lang.output")
		vim.cmd.edit(t.file("a.txt", { "a" }))
		local source = vim.api.nvim_get_current_buf()
		vim.cmd("vsplit " .. t.file("b.txt", { "b" }))
		vim.cmd("wincmd h")
		output.show({ title = "probe asm", lines = { "x" }, source = source, mode = "split", link = false })
		vim.cmd("vsplit " .. t.file("c.txt", { "c" }))
		ws.enforce_two()
		local visible = {}
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			visible[vim.api.nvim_win_get_buf(win)] = true
		end
		t.ok(visible[source], "the rendering's source was closed")
		pcall(output.close, "probe asm")
	end)
end)
