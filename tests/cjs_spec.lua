--- Regression tests for C, C++, JavaScript and TypeScript shapes the bug hunt found
--- broken in the refactoring engine.
local t = require("tests.harness")
local syntax = require("features.refactor.syntax")
local locals = require("features.refactor.locals")
local signature = require("features.refactor.ops.signature")

---@param lang string
---@return boolean
local function has_parser(lang)
	return (pcall(vim.treesitter.language.inspect, lang))
end

--- Parameter names of the first function in a one-line buffer.
---@param line string
---@param ft string
---@return string[]
local function param_names(line, ft)
	local buf = t.buffer({ line }, ft)
	local root = syntax.parsed(buf):parse()[1]:root()
	local names = {}
	local query = vim.treesitter.query.parse(ft, "(parameter_declaration) @p (optional_parameter_declaration) @p")
	for _, node in query:iter_captures(root, buf, 0, -1) do
		table.insert(names, syntax.param_name(node, buf) or "?")
	end
	return names
end

t.describe("c family", function()
	t.it("param_name reads the name, not the type", function()
		if not has_parser("cpp") then
			return
		end
		t.reset()
		t.eq(
			{ "n", "s", "f", "v", "p" },
			param_names("int f(my_t n, std::string &s, const Foo &f, std::vector<int> v, struct foo *p) {}", "cpp")
		)
	end)

	t.it("a C definition is found through its declarator", function()
		if not has_parser("c") then
			return
		end
		t.reset()
		t.buffer({ "int *ptr(int a, int b) {", "  return 0;", "}" }, "c")
		vim.api.nvim_win_set_cursor(0, { 1, 16 })
		local seen = {}
		local real = Snacks.notify.warn
		Snacks.notify.warn = function(msg)
			table.insert(seen, msg)
		end
		-- `b` is last, so there is no neighbour: reaching that message means the
		-- declaration and its list were found.
		pcall(signature.reorder_param, { direction = "next", preview = false })
		Snacks.notify.warn = real
		t.ok(seen[1] and seen[1]:find("neighbouring"), "declaration not found: " .. vim.inspect(seen))
	end)
end)

t.describe("javascript", function()
	t.it("inherited locals queries do not double every reference", function()
		if not has_parser("javascript") then
			return
		end
		t.reset()
		local buf = t.buffer({ "function unused(a, b) {", "  return a;", "}" }, "javascript")
		t.eq(1, #locals.references(buf, "b"), "the parameter was counted twice")
	end)

	t.it("a single-parameter arrow does not edit the function around it", function()
		if not has_parser("typescript") then
			return
		end
		t.reset()
		local buf = t.buffer({ "function outer(x: number) {", "  const single = y => y * x;", "}" }, "typescript")
		vim.api.nvim_win_set_cursor(0, { 2, 17 })
		local real = Snacks.notify.warn
		Snacks.notify.warn = function() end
		pcall(signature.add_param, { spec = "depth", preview = false })
		Snacks.notify.warn = real
		t.eq("function outer(x: number) {", vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
	end)
end)
