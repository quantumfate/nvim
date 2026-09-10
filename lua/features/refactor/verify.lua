--- Checking a refactoring against the language server after it lands.
---
--- The engine cannot predict type-level breakage — that needs a semantic model
--- treesitter does not have. But it does not have to: the server already has one, and
--- it will say so if the edits broke something. So instead of predicting, apply and
--- ask. Removing a still-used parameter comes back as "Undefined global `b`" and
--- "expects a maximum of 1 argument(s) but instead it is receiving 2", which is
--- exactly the conflict that could not be computed in advance.
---
--- Safe only because undo is: this reports new errors and offers to take the change
--- back, and taking it back is now a single verified operation.
---@class refactor.verify
local M = {}

---@class refactor.DiagKey
---@field bufnr integer
---@field lnum integer
---@field message string

--- A comparable fingerprint for one diagnostic. Line and message, not position:
--- an edit shifts columns around without changing what is wrong.
---@param bufnr integer
---@param d vim.Diagnostic
---@return string
local function key(bufnr, d)
	return ("%d\0%s"):format(bufnr, d.message)
end

--- Severities worth reporting. Warnings are included deliberately: the diagnostics
--- that matter most here are exactly the ones lenient servers rank as warnings —
--- lua_ls reports both "Undefined global `b`" and "expects a maximum of 1 argument(s)
--- but instead it is receiving 2" at WARN, and those are the two failures a bad
--- signature change actually causes.
local SEVERITIES = { vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN }

--- Diagnostics worth reporting for a set of buffers, as a set of fingerprints.
---@param bufnrs integer[]
---@return table<string, { bufnr: integer, d: vim.Diagnostic }>
function M.snapshot(bufnrs)
	local out = {}
	for _, bufnr in ipairs(bufnrs) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			for _, d in ipairs(vim.diagnostic.get(bufnr, { severity = SEVERITIES })) do
				out[key(bufnr, d)] = { bufnr = bufnr, d = d }
			end
		end
	end
	return out
end

--- Buffers in a plan that have a server attached, since only those can be checked.
---@param plan refactor.Plan
---@return integer[]
function M.checkable(plan)
	local out = {}
	for bufnr in pairs(plan.edits) do
		if vim.api.nvim_buf_is_valid(bufnr) and #vim.lsp.get_clients({ bufnr = bufnr }) > 0 then
			table.insert(out, bufnr)
		end
	end
	return out
end

--- Waits for diagnostics to settle, then reports errors the refactoring introduced.
---
--- Compared against a baseline rather than counted: a file that already had errors
--- before the refactoring should not make every refactoring look like it broke it.
---@param plan refactor.Plan
---@param baseline table<string, table> From `M.snapshot` before the edits
---@param opts? { timeout?: integer }
---@return string? reason Set when verification could not run
function M.check(plan, baseline, opts)
	opts = opts or {}
	local bufnrs = M.checkable(plan)
	if #bufnrs == 0 then
		-- Nothing to ask. Silence here would read as "verified and clean", which is the
		-- opposite of what happened.
		return "no language server on any edited file"
	end

	-- Servers publish diagnostics on their own schedule. Rather than a fixed sleep,
	-- wait for a publish and then let it settle, giving up quietly on a slow server —
	-- a verification that never arrives must not block the editor.
	local settled = false
	local timer = assert(vim.uv.new_timer())
	local seen = 0

	local group = vim.api.nvim_create_augroup("refactor_verify", { clear = true })
	vim.api.nvim_create_autocmd("DiagnosticChanged", {
		group = group,
		callback = function()
			seen = seen + 1
			timer:stop()
			timer:start(400, 0, function()
				vim.schedule(function()
					if not settled then
						settled = true
						M.report(plan, baseline, bufnrs)
					end
				end)
			end)
		end,
	})

	vim.defer_fn(function()
		if not settled then
			settled = true
			timer:stop()
			pcall(vim.api.nvim_del_augroup_by_id, group)
			if seen > 0 then
				M.report(plan, baseline, bufnrs)
			else
				-- The server never published anything in the window. Not the same as a
				-- clean result, and the difference is the whole point of saying so.
				Snacks.notify.warn(
					("%s applied, but not verified: no diagnostics arrived within %dms"):format(
						plan.title,
						opts.timeout or 5000
					),
					{ title = "Refactor" }
				)
			end
		end
	end, opts.timeout or 5000)
end

--- Notifies about errors that appeared, and offers to undo.
---@param plan refactor.Plan
---@param baseline table<string, table>
---@param bufnrs integer[]
function M.report(plan, baseline, bufnrs)
	pcall(vim.api.nvim_del_augroup_by_name, "refactor_verify")

	local introduced = {}
	for k, entry in pairs(M.snapshot(bufnrs)) do
		if not baseline[k] then
			table.insert(introduced, entry)
		end
	end

	if #introduced == 0 then
		return
	end

	table.sort(introduced, function(a, b)
		return a.d.lnum < b.d.lnum
	end)

	local items, lines = {}, {}
	for _, entry in ipairs(introduced) do
		table.insert(items, {
			bufnr = entry.bufnr,
			lnum = entry.d.lnum + 1,
			col = entry.d.col + 1,
			text = entry.d.message,
		})
		if #lines < 4 then
			table.insert(
				lines,
				("  %s:%d %s"):format(
					vim.fn.fnamemodify(vim.api.nvim_buf_get_name(entry.bufnr), ":t"),
					entry.d.lnum + 1,
					entry.d.message
				)
			)
		end
	end
	if #introduced > #lines then
		table.insert(lines, ("  …and %d more"):format(#introduced - #lines))
	end

	vim.fn.setqflist({}, " ", { title = plan.title .. " (introduced problems)", items = items })
	Snacks.notify.error(
		("%s introduced %d problem(s):\n%s\n\n:RefactorUndo to take it back"):format(
			plan.title,
			#introduced,
			table.concat(lines, "\n")
		),
		{ title = "Refactor" }
	)
end

return M
