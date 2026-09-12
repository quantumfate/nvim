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

	t.it("drives add, remove, and reorder live against ts_ls and validates with tsc", function()
		if
			vim.fn.executable("typescript-language-server") == 0
			or vim.fn.executable("tsc") == 0
			or not has_parser("typescript")
		then
			return
		end
		t.reset()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		local tsconfig = dir .. "/tsconfig.json"
		local file = dir .. "/index.ts"
		vim.fn.writefile({
			'{ "compilerOptions": { "target": "ES2022", "module": "NodeNext", "strict": true } }',
		}, tsconfig)
		vim.fn.writefile({
			"const extra = true;",
			"function f(a: string): void;",
			"function f(a: number): void;",
			"function f(a: any) {}",
			"",
			"f(1);",
			"f.apply(null, [1]);",
			"",
			"class Box {",
			"  constructor(a: number, b: string) {}",
			"}",
			"",
			'const b = new Box(1, "hello");',
		}, file)

		vim.cmd.edit(file)
		local bufnr = vim.api.nvim_get_current_buf()

		local client_id = vim.lsp.start({
			name = "ts_ls",
			cmd = { "typescript-language-server", "--stdio" },
			root_dir = dir,
		})
		assert(client_id, "failed to start ts_ls")

		local ok = vim.wait(15000, function()
			local c = vim.lsp.get_client_by_id(client_id)
			return not not (c and c.initialized and vim.lsp.buf_is_attached(bufnr, client_id))
		end, 100)
		t.ok(ok, "ts_ls did not initialize in time")

		-- 1. Reorder params on Box constructor: swap a and b
		vim.api.nvim_win_set_cursor(0, { 10, 15 })
		local reordered = false
		local real_finish = Plan.finish
		Plan.finish = function(plan, opts)
			real_finish(plan, opts)
			reordered = true
		end
		signature.reorder_param({ direction = "next", preview = false })
		vim.wait(10000, function()
			return reordered
		end, 100)
		t.ok(reordered, "reorder_param failed to complete")

		-- 2. Remove parameter a from Box constructor (after swap, a is at index 1)
		vim.api.nvim_win_set_cursor(0, { 10, 26 })
		local removed = false
		Plan.finish = function(plan, opts)
			real_finish(plan, opts)
			removed = true
		end
		signature.remove_param({ preview = false })
		vim.wait(10000, function()
			return removed
		end, 100)
		t.ok(removed, "remove_param failed to complete")

		-- 3. Add parameter extra to f (standing on implementation)
		vim.api.nvim_win_set_cursor(0, { 4, 11 })
		local added = false
		local plan_ref = nil
		Plan.finish = function(plan, opts)
			plan_ref = plan
			real_finish(plan, opts)
			added = true
		end
		signature.add_param({ spec = "extra: boolean", preview = false })
		vim.wait(10000, function()
			return added
		end, 100)
		t.ok(added, "add_param failed to complete")
		assert(plan_ref)
		t.ok(skips(plan_ref):find("called through .apply", 1, true), "did not skip .apply call")

		Plan.finish = real_finish
		vim.cmd("write")

		-- 4. Verify result compiles cleanly with tsc --noEmit
		local res = vim.system({ "tsc", "--noEmit", "--project", tsconfig }, { text = true, cwd = dir }):wait(30000)
		t.eq(0, res.code, "tsc --noEmit failed after refactors:\n" .. (res.stdout or "") .. "\n" .. (res.stderr or ""))

		-- Stop client and clean up
		local cl = vim.lsp.get_client_by_id(client_id)
		if cl then
			cl:stop()
		end
		pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
		pcall(vim.fn.delete, dir, "rf")
	end)
end)

t.describe("signature trait across workspace crates", function()
	t.it("updates trait definition in sibling crate and impls/calls in app crate", function()
		if vim.fn.executable("rust-analyzer") == 0 or vim.fn.executable("cargo") == 0 or not has_parser("rust") then
			return
		end
		t.reset()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir .. "/crates/shared/src", "p")
		vim.fn.mkdir(dir .. "/crates/app/src", "p")

		vim.fn.writefile({
			"[workspace]",
			'members = ["crates/shared", "crates/app"]',
			'resolver = "2"',
		}, dir .. "/Cargo.toml")

		vim.fn.writefile({
			"[package]",
			'name = "shared"',
			'version = "0.1.0"',
			'edition = "2021"',
		}, dir .. "/crates/shared/Cargo.toml")

		vim.fn.writefile({
			"pub trait Shape {",
			"    fn area(&self, factor: i32) -> i32;",
			"}",
		}, dir .. "/crates/shared/src/lib.rs")

		vim.fn.writefile({
			"[package]",
			'name = "app"',
			'version = "0.1.0"',
			'edition = "2021"',
			"",
			"[dependencies]",
			'shared = { path = "../shared" }',
		}, dir .. "/crates/app/Cargo.toml")

		vim.fn.writefile({
			"use shared::Shape;",
			"",
			"struct Square;",
			"",
			"impl Shape for Square {",
			"    fn area(&self, factor: i32) -> i32 {",
			"        factor * 4",
			"    }",
			"}",
			"",
			"fn main() {",
			"    let s = Square;",
			"    let bias = 1;",
			'    println!("{}", s.area(2));',
			"}",
		}, dir .. "/crates/app/src/main.rs")

		vim.cmd.edit(dir .. "/crates/app/src/main.rs")
		local bufnr = vim.api.nvim_get_current_buf()

		local client_id = vim.lsp.start({
			name = "rust_analyzer",
			cmd = { "rust-analyzer" },
			root_dir = dir,
		})
		assert(client_id, "failed to start rust-analyzer")

		local ok = vim.wait(30000, function()
			local c = vim.lsp.get_client_by_id(client_id)
			return not not (c and c.initialized and vim.lsp.buf_is_attached(bufnr, client_id))
		end, 200)
		t.ok(ok, "rust-analyzer did not initialize in time")

		-- Wait for indexing
		vim.wait(3000, function()
			return false
		end)

		-- Stand on factor: i32 in impl Shape for Square (line 8, col 23)
		vim.api.nvim_win_set_cursor(0, { 8, 23 })

		local plan_done = nil
		local real_finish = Plan.finish
		Plan.finish = function(plan, opts)
			plan_done = plan
			real_finish(plan, opts)
		end

		signature.add_param({ spec = "bias: i32", preview = false })
		vim.wait(20000, function()
			return plan_done ~= nil
		end, 200)

		t.ok(plan_done ~= nil, "no plan produced")
		assert(plan_done)
		t.eq(0, #plan_done.conflicts, "unexpected conflicts: " .. vim.inspect(plan_done.conflicts))

		-- Both the app crate file and the shared crate file must be edited
		local edited_files = {}
		for b in pairs(plan_done.edits) do
			if vim.api.nvim_buf_is_valid(b) then
				table.insert(edited_files, vim.fs.basename(vim.api.nvim_buf_get_name(b)))
				if vim.bo[b].modified then
					vim.api.nvim_buf_call(b, function()
						vim.cmd("write")
					end)
				end
			end
		end
		table.sort(edited_files)
		t.ok(vim.tbl_contains(edited_files, "lib.rs"), "shared trait lib.rs was not edited")
		t.ok(vim.tbl_contains(edited_files, "main.rs"), "app main.rs was not edited")

		Plan.finish = real_finish

		-- Verify with cargo check across the workspace
		local res = vim.system(
			{ "cargo", "check", "--manifest-path", dir .. "/Cargo.toml" },
			{ text = true, cwd = dir }
		)
			:wait(30000)
		t.eq(0, res.code, "cargo check failed after multi-crate trait refactor:\n" .. (res.stderr or ""))

		local cl = vim.lsp.get_client_by_id(client_id)
		if cl then
			cl:stop()
		end
		pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
		pcall(vim.fn.delete, dir, "rf")
	end)
end)
