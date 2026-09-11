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

	-- clangd reads other files' headers from disk, not from unsaved buffers: until an
	-- edited header is written, every file including it reports the old prototype as a
	-- conflict. Those files are checked once the header is saved.
	local headers = vim.tbl_filter(function(b)
		return vim.bo[b].modified and vim.api.nvim_buf_get_name(b):match("%.h[hp]*$") ~= nil
	end, bufnrs)
	if #headers > 0 and #headers < #bufnrs then
		local now = headers
		local later = vim.tbl_filter(function(b)
			return not vim.tbl_contains(headers, b)
		end, bufnrs)
		Snacks.notify.info(
			("Verifying %s now; %d other file(s) once it is saved"):format(
				vim.fs.basename(vim.api.nvim_buf_get_name(headers[1])),
				#later
			),
			{ title = "Refactor" }
		)
		vim.api.nvim_create_autocmd("BufWritePost", {
			buffer = headers[1],
			once = true,
			callback = function()
				M.wait_and_report(plan, baseline, later, opts)
			end,
		})
		bufnrs = now
	end

	M.wait_and_report(plan, baseline, bufnrs, opts)
end

--- Waits until every buffer has diagnostics newer than the edit, then reports.
---
--- "Any publish" was not enough: clangd sends a pre-edit version right after the change,
--- rust-analyzer publishes stale versions, and ts_ls sends two waves without a version.
--- A publish counts for a buffer only when its version is the edited one or newer, or,
--- when the server sends no version, when it arrives after the edit.
---@param plan refactor.Plan
---@param baseline table<string, table>
---@param bufnrs integer[]
---@param opts { timeout?: integer }
function M.wait_and_report(plan, baseline, bufnrs, opts)
	local want, fresh = {}, {}
	for _, b in ipairs(bufnrs) do
		want[vim.uri_from_bufnr(b)] = { bufnr = b, version = vim.lsp.util.buf_versions[b] or 0 }
	end
	local slow = false
	for _, b in ipairs(bufnrs) do
		for _, client in ipairs(vim.lsp.get_clients({ bufnr = b })) do
			slow = slow or client.name == "rust_analyzer"
		end
	end
	local timeout = opts.timeout or (slow and 20000 or 10000)

	local settled = false
	local timer = assert(vim.uv.new_timer())
	local method = "textDocument/publishDiagnostics"
	local original = vim.lsp.handlers[method]

	local function all_fresh()
		for _, b in ipairs(bufnrs) do
			if not fresh[b] then
				return false
			end
		end
		return true
	end

	local function finish()
		if settled then
			return
		end
		settled = true
		timer:stop()
		vim.lsp.handlers[method] = original
		local checked = vim.tbl_filter(function(b)
			return fresh[b]
		end, bufnrs)
		local unchecked = #bufnrs - #checked
		if #checked == 0 then
			-- Not the same as a clean result, and the difference is the whole point of
			-- saying so.
			Snacks.notify.warn(
				("%s applied, but not verified: no current diagnostics within %dms"):format(plan.title, timeout),
				{ title = "Refactor" }
			)
			return
		end
		M.report(plan, baseline, checked)
		if unchecked > 0 then
			Snacks.notify.warn(("%d file(s) were not verified: their server did not answer in time"):format(unchecked), {
				title = "Refactor",
			})
		end
	end

	vim.lsp.handlers[method] = function(err, result, ctx, config)
		local entry = result and want[result.uri]
		if entry and (result.version == nil or result.version >= entry.version) then
			fresh[entry.bufnr] = true
		end
		local ret = original(err, result, ctx, config)
		if all_fresh() then
			timer:stop()
			timer:start(400, 0, vim.schedule_wrap(finish))
		end
		return ret
	end

	vim.defer_fn(finish, timeout)
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
