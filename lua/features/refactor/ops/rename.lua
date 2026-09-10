--- Rename, including the occurrences in comments and strings that LSP rename drops.
---
--- `textDocument/rename` only touches identifiers the server resolved, which is
--- correct and incomplete: rename a function and its own doc comment still describes
--- the old name. IntelliJ asks "search in comments and strings?" for exactly this.
--- Here those occurrences are found separately and shown in the preview, so they are
--- reviewed rather than trusted.
---@class refactor.ops.rename
local M = {}

local usages = require("features.refactor.usages")
local Plan = require("features.refactor.plan")

--- Renames the symbol under the cursor everywhere, prose included.
--- `prose` controls the comment and string pass, which is additive: with it off the
--- rename is still complete and correct, it just leaves stale comments behind.
--- `prose = "loose"` takes every whole-word hit instead of only symbol-shaped ones.
---@param opts? { name?: string, prose?: boolean|"loose", preview?: boolean }
function M.run(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_get_current_buf()
	local old = vim.fn.expand("<cword>")
	if old == "" then
		Snacks.notify.warn("No symbol under the cursor", { title = "Refactor" })
		return
	end

	local proceed = function(new)
		if not new or vim.trim(new) == "" or new == old then
			return
		end
		new = vim.trim(new)

		local client = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/rename" })[1]
		local plan = Plan.new(("Rename %s → %s"):format(old, new))

		--- Adds the comment and string occurrences across every buffer the plan touches,
		--- then hands over. Done last so it can cover files the server pulled in.
		local function add_prose()
			if opts.prose == false then
				Plan.finish(plan, opts)
				return
			end

			local seen = {}
			for target in pairs(plan.edits) do
				seen[target] = true
			end
			seen[bufnr] = true

			for target in pairs(seen) do
				for _, usage in ipairs(usages.prose(target, old, { loose = opts.prose == "loose" })) do
					plan:edit(target, { range = usage.range, newText = new })
				end
			end
			Plan.finish(plan, opts)
		end

		if not client then
			plan:note("skip", bufnr, 0, 0, "no language server: only comments and strings were renamed")
			add_prose()
			return
		end

		local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
		params.newName = new
		client:request("textDocument/rename", params, function(err, result)
			if err or not result then
				plan:note("conflict", bufnr, 0, 0, "rename failed: " .. (err and err.message or "no result"))
				Plan.finish(plan, opts)
				return
			end

			-- A WorkspaceEdit arrives as either `changes` or `documentChanges`.
			for uri, edits in pairs(result.changes or {}) do
				plan:edits_for(plan:bufnr(uri), edits)
			end
			for _, change in ipairs(result.documentChanges or {}) do
				if change.textDocument and change.edits then
					plan:edits_for(plan:bufnr(change.textDocument.uri), change.edits)
				end
			end
			add_prose()
		end, bufnr)
	end

	if opts.name then
		proceed(opts.name)
	else
		vim.ui.input({ prompt = "Rename to: ", default = old }, proceed)
	end
end

return M
