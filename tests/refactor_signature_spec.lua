--- Change-signature shapes that reach past one declaration: Python overrides, C
--- functions defined through a macro, nested parameter lists and TS call forms.
--- References are stubbed, so no language server runs; each shape was also driven
--- against its real server when written.
local t = require("tests.harness")
local Plan = require("features.refactor.plan")
local usages = require("features.refactor.usages")
local signature = require("features.refactor.ops.signature")

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

--- The plan an op would apply, captured instead of applied. `refs` stands in for the
--- language server's references as `{ row, col }` pairs in the current buffer.
---@param fn fun()
---@param refs? integer[][]
---@return refactor.Plan?
local function planned(fn, refs)
	local real, got = Plan.finish, nil
	Plan.finish = function(plan)
		Plan.done()
		got = plan
	end
	local notify, lsp = Snacks.notify.warn, usages.lsp
	Snacks.notify.warn = function() end
	if refs then
		local buf = vim.api.nvim_get_current_buf()
		usages.lsp = function(_, _, on_done)
			on_done(
				vim.tbl_map(function(pos)
					local p = { line = pos[1], character = pos[2] }
					return { bufnr = buf, range = { start = p, ["end"] = p }, kind = "code" }
				end, refs),
				{ offset_encoding = "utf-8", name = "stub" }
			)
		end
	end
	local ok, err = pcall(fn)
	vim.wait(3000, function()
		return got ~= nil
	end, 20)
	Plan.finish, Snacks.notify.warn, usages.lsp = real, notify, lsp
	assert(ok, err)
	return got
end

---@param plan refactor.Plan
---@return string
local function conflicts(plan)
	return table.concat(
		vim.tbl_map(function(c)
			return c.text
		end, plan.conflicts),
		"\n"
	)
end

---@param plan refactor.Plan
---@return string
local function skips(plan)
	return table.concat(
		vim.tbl_map(function(c)
			return c.text
		end, plan.skips),
		"\n"
	)
end

--- Start rows of every edit in the plan's only buffer, sorted.
---@param plan refactor.Plan
---@return integer[]
local function edit_rows(plan)
	local rows = {}
	for _, edits in pairs(plan.edits) do
		for _, e in ipairs(edits) do
			table.insert(rows, e.range.start.line)
		end
	end
	table.sort(rows)
	return rows
end

local HIERARCHY = {
	"class Base:",
	"    def area(self, x):",
	"        return x",
	"class Child(Base):",
	"    def area(self, x):",
	"        return super().area(x)",
	"class GrandChild(Child):",
	"    def area(self, x):",
	"        return x",
	"class Other:",
	"    def area(self, x):",
	"        return x",
}

t.describe("signature python overrides", function()
	t.it("adding a parameter reaches base and subclass overrides", function()
		if not has_parser("python") then
			return
		end
		t.reset()
		t.buffer(HIERARCHY, "python")
		vim.api.nvim_win_set_cursor(0, { 5, 20 })
		local plan = planned(function()
			signature.add_param({ spec = "y", preview = false })
		end)
		t.ok(plan, "no plan")
		assert(plan)
		-- Base, Child and GrandChild; the unrelated Other is left alone.
		t.eq({ 1, 4, 7 }, edit_rows(plan))
		t.eq("", conflicts(plan))
	end)

	t.it("an optional parameter still reaches the overrides", function()
		if not has_parser("python") then
			return
		end
		t.reset()
		t.buffer(HIERARCHY, "python")
		vim.api.nvim_win_set_cursor(0, { 2, 19 })
		local plan = planned(function()
			signature.add_param({ spec = "y=0", preview = false })
		end)
		t.ok(plan, "no plan")
		assert(plan)
		t.eq({ 1, 4, 7 }, edit_rows(plan))
	end)

	t.it("an override with a different parameter list is a conflict naming it", function()
		if not has_parser("python") then
			return
		end
		t.reset()
		local lines = vim.deepcopy(HIERARCHY)
		lines[8] = "    def area(self, x, scale):"
		t.buffer(lines, "python")
		vim.api.nvim_win_set_cursor(0, { 2, 19 })
		local plan = planned(function()
			signature.remove_param({ preview = false })
		end)
		t.ok(plan and conflicts(plan):find("GrandChild.area", 1, true), plan and conflicts(plan) or "no plan")
	end)

	t.it("a parameter still used in an override is a conflict", function()
		if not has_parser("python") then
			return
		end
		t.reset()
		local lines = vim.deepcopy(HIERARCHY)
		lines[2] = "    def area(self, x, y):"
		lines[5] = "    def area(self, x, y):"
		lines[6] = "        return y"
		lines[8] = "    def area(self, x, y):"
		t.buffer(lines, "python")
		vim.api.nvim_win_set_cursor(0, { 2, 22 })
		local plan = planned(function()
			signature.remove_param({ preview = false })
		end)
		t.ok(plan and conflicts(plan):find("Child.area", 1, true), plan and conflicts(plan) or "no plan")
	end)

	t.it("constructors are not treated as overrides", function()
		if not has_parser("python") then
			return
		end
		t.reset()
		t.buffer({
			"class Base:",
			"    def __init__(self, x):",
			"        self.x = x",
			"class Child(Base):",
			"    def __init__(self, x):",
			"        super().__init__(x)",
		}, "python")
		vim.api.nvim_win_set_cursor(0, { 2, 23 })
		local plan = planned(function()
			signature.add_param({ spec = "y", preview = false })
		end)
		assert(plan)
		t.eq({ 1 }, edit_rows(plan))
	end)

	t.it("`Base.method(self, …)` inside a subclass counts the explicit receiver", function()
		if not has_parser("python") then
			return
		end
		t.reset()
		local buf = t.buffer({ "Base.area(self, 1)" }, "python")
		local call = vim.treesitter.get_parser(buf, "python"):parse()[1]:root():named_descendant_for_range(0, 0, 0, 18)
		while call and call:type() ~= "call" do
			call = call:parent()
		end
		assert(call)
		local shape = require("features.refactor.langs").python.calls[1]
		t.eq(1, shape.implicit(call, { self_receiver = true, owner = "Child", owners = { Base = true } }, buf))
	end)
end)

t.describe("signature c", function()
	t.it("a function defined through a macro is a conflict", function()
		if not has_parser("c") then
			return
		end
		t.reset()
		local path = t.file("m.c", {
			"int f(int a, int b);",
			"DEFINE2(f, int, a, int, b) { return a + b; }",
			"static SYSCALL_DEFINE2(f, int, a, int, b) { return a; }",
			"int main(void) { return f(1, 2); }",
		})
		vim.cmd.edit(path)
		vim.api.nvim_win_set_cursor(0, { 1, 10 })
		local plan = planned(function()
			signature.remove_param({ preview = false })
		end, { { 0, 4 }, { 1, 8 }, { 2, 23 }, { 3, 24 } })
		t.ok(plan, "no plan")
		assert(plan)
		local _, count = conflicts(plan):gsub("defined through a macro", "")
		t.eq(2, count, conflicts(plan))
		t.eq({ 0, 3 }, edit_rows(plan), "the prototype and the call are still rewritten")
	end)

	t.it("refuses a cursor inside a function-pointer parameter's own list", function()
		if not has_parser("c") then
			return
		end
		t.reset()
		t.buffer({ "int apply(int (*fp)(int, int), int n) { return fp(n, n); }" }, "c")
		for _, op in ipairs({ "remove_param", "reorder_param" }) do
			vim.api.nvim_win_set_cursor(0, { 1, 20 })
			local seen = warnings(function()
				signature[op]({ preview = false })
			end)
			t.ok(seen[1] and seen[1]:find("nested parameter list"), op .. ": " .. vim.inspect(seen))
		end
	end)

	t.it("the function-pointer parameter itself can still be removed", function()
		if not has_parser("c") then
			return
		end
		t.reset()
		t.buffer({ "int apply(int (*fp)(int, int), int n) { return n; }" }, "c")
		vim.api.nvim_win_set_cursor(0, { 1, 16 })
		local plan = planned(function()
			signature.remove_param({ preview = false })
		end, {})
		t.ok(plan and not conflicts(plan):find("nested"), "refused the outer parameter")
	end)
end)

t.describe("signature typescript", function()
	t.it("overloads, new and .apply", function()
		if not has_parser("typescript") then
			return
		end
		t.reset()
		t.buffer({
			"function f(a: string): void;",
			"function f(a: number): void;",
			"function f(a: any) {}",
			"f(1);",
			"f.apply(null, [1]);",
		}, "typescript")
		vim.api.nvim_win_set_cursor(0, { 3, 11 })
		local plan = planned(function()
			signature.add_param({ spec = "b:number", preview = false })
		end, { { 0, 9 }, { 1, 9 }, { 2, 9 }, { 3, 0 }, { 4, 0 } })
		t.ok(plan, "no plan")
		assert(plan)
		t.eq({ 0, 1, 2, 3 }, edit_rows(plan))
		t.ok(skips(plan):find("called through .apply", 1, true), skips(plan))
	end)

	t.it("a constructor's `new` call sites are rewritten", function()
		if not has_parser("typescript") then
			return
		end
		t.reset()
		t.buffer({
			"class Box {",
			"  constructor(a: number) {}",
			"}",
			"const b = new Box(1);",
		}, "typescript")
		vim.api.nvim_win_set_cursor(0, { 2, 15 })
		local plan = planned(function()
			signature.remove_param({ preview = false })
		end, { { 3, 14 } })
		t.ok(plan, "no plan")
		assert(plan)
		t.eq({ 1, 3 }, edit_rows(plan))
	end)

	t.it("refuses a cursor inside a callback type's parameters", function()
		if not has_parser("typescript") then
			return
		end
		t.reset()
		t.buffer({ "function run(cb: (x: number, y: number) => void, n: number) {}" }, "typescript")
		vim.api.nvim_win_set_cursor(0, { 1, 18 })
		local seen = warnings(function()
			signature.remove_param({ preview = false })
		end)
		t.ok(seen[1] and seen[1]:find("nested parameter list"), vim.inspect(seen))
	end)
end)
