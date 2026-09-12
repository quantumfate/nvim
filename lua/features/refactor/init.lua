--- The refactoring engine: one registry, one plan type, one way to apply.
---
--- Every entry below builds a `refactor.Plan` and applies none of it. Preview,
--- conflict gating and cross-file undo live in `plan.lua` and `preview.lua`, so a new
--- refactoring is the analysis and nothing else — which is the only reason there are
--- this many of them rather than one.
---
--- Three sources of truth, in order of how much they know:
---   language server   resolved references, workspace rename, real code actions
---   locals.scm        scopes and bindings: collisions, safe delete, extract
---   treesitter        syntax: where the parameter list is, where the function ends
---@class refactor
local M = {}

---@class refactor.Op
---@field desc string
---@field run fun(opts?: table)
---@field mode? string|string[] Defaults to normal

--- Everything `:Refactor` and the picker offer.
---@type table<string, refactor.Op>
M.ops = {
	add_param = {
		desc = "Add parameter",
		run = function(opts)
			require("features.refactor.ops.signature").add_param(opts)
		end,
	},
	remove_param = {
		desc = "Remove parameter",
		run = function(opts)
			require("features.refactor.ops.signature").remove_param(opts)
		end,
	},
	reorder_param_next = {
		desc = "Move parameter right",
		run = function(opts)
			require("features.refactor.ops.signature").reorder_param(
				vim.tbl_extend("force", { direction = "next" }, opts or {})
			)
		end,
	},
	reorder_param_prev = {
		desc = "Move parameter left",
		run = function(opts)
			require("features.refactor.ops.signature").reorder_param(
				vim.tbl_extend("force", { direction = "prev" }, opts or {})
			)
		end,
	},
	rename = {
		desc = "Rename (incl. comments and strings)",
		run = function(opts)
			require("features.refactor.ops.rename").run(opts)
		end,
	},
	safe_delete = {
		desc = "Safe delete",
		run = function(opts)
			require("features.refactor.ops.safe_delete").run(opts)
		end,
	},
	extract_variable = {
		desc = "Extract variable",
		mode = "x",
		run = function(opts)
			require("features.refactor.ops.variable").extract(opts)
		end,
	},
	inline_variable = {
		desc = "Inline variable",
		run = function(opts)
			require("features.refactor.ops.variable").inline(opts)
		end,
	},
	move_to_file = {
		desc = "Move to file",
		run = function(opts)
			require("features.refactor.ops.move").run(opts)
		end,
	},
	extract_function = {
		desc = "Extract function / block (refactoring.nvim)",
		mode = { "n", "x" },
		run = function()
			-- prefer_ex_cmd populates `:Refactor <name> ` so the edit renders in the
			-- inccommand preview before it lands — that plugin's own preview mechanism.
			local ok, refactoring = pcall(require, "refactoring")
			if not ok then
				Snacks.notify.warn("refactoring.nvim is not loaded", { title = "Refactor" })
				return
			end
			refactoring.select_refactor({ prefer_ex_cmd = true })
		end,
	},
	server = {
		desc = "Server code actions (rust-analyzer, ts_ls, …)",
		run = function()
			M.server_actions()
		end,
	},
}

--- The refactorings a language server offers for the cursor, as code actions.
---
--- This is the ceiling the treesitter engine cannot reach on its own: extract
--- interface, pull member up, change type hierarchy all need resolved types. Where a
--- server implements them they are already here for the asking, and where none does
--- (lua, zig) this menu is simply empty — which is the honest answer.
function M.server_actions()
	-- Deliberately unfiltered. `only = { "refactor" }` looks right and hides most of
	-- what is on offer: rust-analyzer sends many assists with no `kind` at all, so a
	-- kind filter drops "Generate trait from impl" — the extract-interface refactoring
	-- this menu exists to reach — while keeping "Inline into all callers".
	vim.lsp.buf.code_action({
		context = { diagnostics = {} },
		apply = false,
	})
end

--- Picks a refactoring, offering only the ones that apply to the current mode.
---
--- One menu for the whole `<leader>r` prefix, this engine's ops and
--- refactoring.nvim's alike: two pickers for one prefix is how you end up not knowing
--- which one has the refactoring you want.
function M.select()
	local mode = vim.fn.mode():sub(1, 1) == "v" and "x" or "n"
	local names = {}
	for name, op in pairs(M.ops) do
		local m = op.mode
		local modes = type(m) == "table" and m or { m or "n" }
		---@cast modes string[]
		if vim.tbl_contains(modes, mode) then
			table.insert(names, name)
		end
	end
	table.sort(names)

	vim.ui.select(names, {
		prompt = "Refactor",
		format_item = function(name)
			return M.ops[name].desc
		end,
	}, function(name)
		if name then
			M.ops[name].run({})
		end
	end)
end

--- Registers :Refactor, :RefactorUndo and the <leader>r bindings.
function M.setup()
	vim.api.nvim_create_user_command("Refactor", function(args)
		if args.args == "" then
			M.select()
			return
		end
		local op = M.ops[args.args]
		if not op then
			Snacks.notify.error("Unknown refactoring: " .. args.args, { title = "Refactor" })
			return
		end
		op.run({})
	end, {
		nargs = "?",
		range = true,
		complete = function(lead)
			return vim.tbl_filter(function(name)
				return name:find(lead, 1, true) == 1
			end, vim.tbl_keys(M.ops))
		end,
		desc = "Run a refactoring (no argument opens the menu)",
	})

	vim.api.nvim_create_user_command("RefactorUndo", function(args)
		require("features.refactor.plan").undo({ force = args.bang })
	end, {
		bang = true,
		desc = "Undo the last refactoring across every file it touched (! discards later edits)",
	})
end

return M
