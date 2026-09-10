--- A refactoring expressed as data before any buffer is touched.
---
--- Every refactoring builds one of these and applies none of them itself. That split
--- is what makes preview, conflict gating and cross-file undo shared machinery rather
--- than something each refactoring reimplements — the same reason IntelliJ routes all
--- of its refactorings through one processor.
---
--- Four outcomes a refactoring can record:
---   edit       a change to make
---   conflict   a reason the refactoring is unsafe; any conflict blocks apply
---   skip       a site that could not be handled but does not make the rest wrong
---   unchecked  a guard that did not run, and why
---
--- The fourth exists because a guard that found nothing and a guard that never ran
--- look identical from the outside, and only one of them is reassuring. "No conflicts"
--- means something very different in a language with a locals query than in one
--- without, so the plan says which it was rather than letting silence imply safety.
---@class refactor.plan
local M = {}

---@class refactor.Skip
---@field filename string
---@field lnum integer 1-indexed
---@field col integer 1-indexed
---@field text string Why this site was left alone

---@alias refactor.Conflict refactor.Skip

---@class refactor.Plan
---@field title string Shown in the preview and notifications
---@field edits table<integer, lsp.TextEdit[]> Keyed by buffer number
---@field conflicts refactor.Conflict[]
---@field skips refactor.Skip[]
---@field unchecked table<string, string> Guard name -> why it did not run
---@field opened integer[] Buffers this plan loaded itself, which were not open before
local Plan = {}
Plan.__index = Plan

--- The plan applied most recently, for `:RefactorUndo`.
--- The last applied plan. `before` is what to restore, `after` is what apply left
--- behind — undo compares against `after` so it never discards later work.
---@type { title: string, before: table<integer, string[]>, after: table<integer, string[]>, written: integer[], cursor: integer[], win: integer }|nil
local last = nil

--- Buffers opened by any refactoring this session. Ownership is per session, not per
--- plan: once the engine pulled a file in, the user still has not looked at it, so the
--- next refactoring to touch it should write it too rather than leaving it dirty
--- because a previous one happened to load it first.
---@type table<integer, boolean>
local engine_opened = {}

--- Set while a refactoring is mid-flight, so a second one cannot interleave its
--- async callbacks into the first one's plan.
local running = false

--- Claims the engine for one refactoring. Returns false when one is already running.
---@param title string
---@return boolean ok
function M.begin(title)
	if running then
		Snacks.notify.warn("A refactoring is already running", { title = "Refactor" })
		return false
	end
	running = title
	return true
end

--- Releases the claim taken by `begin`.
function M.done()
	running = false
end

---@param title string
---@return refactor.Plan
function M.new(title)
	return setmetatable({ title = title, edits = {}, conflicts = {}, skips = {}, unchecked = {}, opened = {} }, Plan)
end

--- Loads the buffer for a URI, remembering whether this plan is what opened it.
--- Buffers the plan opened are written on apply; ones the user already had are left
--- modified so nothing is saved behind their back.
---@param uri string
---@return integer bufnr
function Plan:bufnr(uri)
	local existing = vim.uri_to_bufnr(uri)
	local was_loaded = vim.api.nvim_buf_is_loaded(existing)
	vim.fn.bufload(existing)
	if not was_loaded or engine_opened[existing] then
		self:adopt(existing)
	end
	return existing
end

--- Records that the plan, not the user, is what loaded this buffer. Only these are
--- written on apply; a file the user already had open is left dirty for review.
---@param bufnr integer
function Plan:adopt(bufnr)
	engine_opened[bufnr] = true
	if not vim.tbl_contains(self.opened, bufnr) then
		table.insert(self.opened, bufnr)
	end
end

--- True when a previous refactoring is what put this buffer in the session.
---@param bufnr integer
---@return boolean
function M.owns(bufnr)
	return engine_opened[bufnr] == true
end

--- `0` is resolved here rather than passed through: apply_text_edits asserts on it,
--- and it would do so long after the mistake was made.
---@param bufnr integer
---@param edit lsp.TextEdit
function Plan:edit(bufnr, edit)
	bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
	self.edits[bufnr] = self.edits[bufnr] or {}
	table.insert(self.edits[bufnr], edit)
end

---@param bufnr integer
---@param edits lsp.TextEdit[]
function Plan:edits_for(bufnr, edits)
	for _, edit in ipairs(edits or {}) do
		self:edit(bufnr, edit)
	end
end

--- Records a position with a reason. `kind` "conflict" blocks apply, "skip" does not.
---@param kind "conflict"|"skip"
---@param bufnr integer
---@param row integer 0-indexed
---@param col integer 0-indexed
---@param text string
function Plan:note(kind, bufnr, row, col, text)
	local entry = {
		filename = vim.api.nvim_buf_get_name(bufnr),
		lnum = row + 1,
		col = col + 1,
		text = text,
	}
	table.insert(kind == "conflict" and self.conflicts or self.skips, entry)
end

--- Records that a safety guard could not run. Shown in the preview, so the gap is
--- visible while there is still a decision to make about it.
---@param guard string Short name, e.g. "collision detection"
---@param reason string Why it did not run
function Plan:skipped_check(guard, reason)
	self.unchecked[guard] = reason
end

--- Number of buffers and edits the plan would change.
---@return integer files, integer edits
function Plan:size()
	local files, edits = 0, 0
	for _, list in pairs(self.edits) do
		files = files + 1
		edits = edits + #list
	end
	return files, edits
end

---@return boolean
function Plan:is_empty()
	return select(2, self:size()) == 0
end

--- Applies every edit, after snapshotting the buffers so the whole change can be
--- undone as one step. Vim's undo is per-buffer, so a twelve-file refactoring would
--- otherwise take twelve undos in twelve buffers; `:RefactorUndo` restores all of them.
---@param opts? { force?: boolean, verify?: boolean } force applies despite conflicts;
--- verify defaults to true and checks the result against the language server
---@return boolean applied
function Plan:apply(opts)
	opts = opts or {}

	if #self.conflicts > 0 and not opts.force then
		self:to_quickfix("conflict")
		Snacks.notify.error(
			("%s: %d conflict(s); nothing changed"):format(self.title, #self.conflicts),
			{ title = "Refactor" }
		)
		return false
	end

	if self:is_empty() then
		Snacks.notify.warn(self.title .. ": nothing to change", { title = "Refactor" })
		return false
	end

	-- Pre-flight. Every reason an edit can fail that is knowable in advance is
	-- cheaper to find now than to roll back afterwards.
	local unusable = {}
	for bufnr in pairs(self.edits) do
		local name = vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) or ("buffer " .. bufnr)
		if not vim.api.nvim_buf_is_valid(bufnr) then
			table.insert(unusable, name .. ": buffer no longer exists")
		elseif not vim.api.nvim_buf_is_loaded(bufnr) then
			table.insert(unusable, name .. ": buffer is not loaded")
		elseif not vim.bo[bufnr].modifiable then
			table.insert(unusable, name .. ": buffer is not modifiable")
		elseif vim.bo[bufnr].readonly then
			table.insert(unusable, name .. ": buffer is read-only")
		end
	end
	if #unusable > 0 then
		Snacks.notify.error(
			("%s: nothing changed\n%s"):format(self.title, table.concat(unusable, "\n")),
			{ title = "Refactor" }
		)
		return false
	end

	local verify = require("features.refactor.verify")
	local baseline = verify.snapshot(verify.checkable(self))

	local before = {}
	for bufnr in pairs(self.edits) do
		before[bufnr] = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	end

	--- Puts every touched buffer back the way it was.
	---@param written integer[] Buffers already written to disk, which must be rewritten
	local function rollback(written)
		for bufnr, lines in pairs(before) do
			if vim.api.nvim_buf_is_valid(bufnr) then
				pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, lines)
			end
		end
		for _, bufnr in ipairs(written or {}) do
			if vim.api.nvim_buf_is_valid(bufnr) then
				vim.api.nvim_buf_call(bufnr, function()
					pcall(vim.cmd, "silent noautocmd write")
				end)
			end
		end
	end

	-- All or nothing. A refactoring that edited three files out of five is worse than
	-- one that edited none: the code no longer compiles and there is no single thing
	-- to undo, because the failure happened before undo state was ever recorded.
	for bufnr, edits in pairs(self.edits) do
		local ok, err = pcall(vim.lsp.util.apply_text_edits, edits, bufnr, "utf-8")
		if not ok then
			rollback()
			Snacks.notify.error(
				("%s: failed on %s, rolled back\n%s"):format(
					self.title,
					vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":~:."),
					tostring(err)
				),
				{ title = "Refactor" }
			)
			return false
		end
	end

	-- Recorded after the edits land: undo restores `before`, but only for buffers that
	-- still look like `after`. Anything typed since is work this must not discard.
	local after = {}
	for bufnr in pairs(self.edits) do
		after[bufnr] = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	end
	last = {
		title = self.title,
		before = before,
		after = after,
		written = {},
		cursor = vim.api.nvim_win_get_cursor(0),
		win = vim.api.nvim_get_current_win(),
	}

	-- Buffers the plan opened were never visible; leaving them modified and hidden is
	-- how edits get lost on exit. Ones the user already had stay dirty for review.
	local written = 0
	for _, bufnr in ipairs(self.opened) do
		if self.edits[bufnr] and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].modified then
			local ok, err = vim.api.nvim_buf_call(bufnr, function()
				return pcall(vim.cmd, "silent noautocmd write")
			end)
			if not (ok and err ~= false) then
				-- A failed write is still a transaction failure: undo the buffers and
				-- put back the files that were already written.
				rollback(last.written)
				last = nil
				Snacks.notify.error(
					("%s: could not write %s, rolled back"):format(
						self.title,
						vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":~:.")
					),
					{ title = "Refactor" }
				)
				return false
			end
			table.insert(last.written, bufnr)
			written = written + 1
		end
	end

	local files, edits = self:size()
	local parts = { ("%d edit(s) in %d file(s)"):format(edits, files) }
	if written > 0 then
		table.insert(parts, ("%d written"):format(written))
	end
	if #self.skips > 0 then
		table.insert(parts, ("%d need attention"):format(#self.skips))
		self:to_quickfix("skip")
	end

	local msg = self.title .. ": " .. table.concat(parts, ", ")
	if #self.skips > 0 then
		Snacks.notify.warn(msg, { title = "Refactor" })
	else
		Snacks.notify.info(msg, { title = "Refactor" })
	end

	-- The server has the type information this engine does not. Ask it whether the
	-- edits broke anything, and say so if they did — or say that nothing asked.
	if opts.verify ~= false then
		local why = verify.check(self, baseline)
		if why then
			Snacks.notify.warn(("%s applied, but not verified: %s"):format(self.title, why), { title = "Refactor" })
		end
	end

	return true
end

--- Sends conflicts or skips to the quickfix list.
---@param kind "conflict"|"skip"
function Plan:to_quickfix(kind)
	local items = kind == "conflict" and self.conflicts or self.skips
	vim.fn.setqflist({}, " ", { title = ("%s (%s)"):format(self.title, kind), items = items })
end

--- Undoes the last applied plan across every buffer it touched.
---@return boolean undone
---@param opts? { force?: boolean } force restores even where the buffer has moved on
function M.undo(opts)
	opts = opts or {}
	if not last then
		Snacks.notify.warn("No refactoring to undo", { title = "Refactor" })
		return false
	end

	-- Restoring a whole-buffer snapshot over a buffer that has been edited since would
	-- silently throw that work away, and there is no vim undo entry to get it back.
	local dirty = {}
	for bufnr, expected in pairs(last.after) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local current = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			if not vim.deep_equal(current, expected) then
				table.insert(dirty, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":~:."))
			end
		end
	end

	if #dirty > 0 and not opts.force then
		Snacks.notify.error(
			("Edited since the refactoring: %s\nUndo would discard that work. :RefactorUndo! to override."):format(
				table.concat(dirty, ", ")
			),
			{ title = "Refactor" }
		)
		return false
	end

	for bufnr, lines in pairs(last.before) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		end
	end

	-- Files apply() wrote have to be written back too, or the buffer says one thing
	-- and the file on disk says another.
	for _, bufnr in ipairs(last.written) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_call(bufnr, function()
				vim.cmd("silent noautocmd write")
			end)
		end
	end
	-- Back to where the refactoring was started from.
	if vim.api.nvim_win_is_valid(last.win) then
		pcall(vim.api.nvim_set_current_win, last.win)
		pcall(vim.api.nvim_win_set_cursor, last.win, last.cursor)
	end

	Snacks.notify.info("Undid " .. last.title, { title = "Refactor" })
	last = nil
	return true
end

--- Previews or applies, depending on opts. Every refactoring ends here.
---
--- Armed by SafeState rather than a timer: ops that ask for a name arrive from inside
--- `vim.ui.input`, and the Enter that submitted the prompt is still in the typeahead.
--- SafeState fires when nvim is idle waiting for input, which is precisely "that key
--- has been consumed".
---@param plan refactor.Plan
---@param opts? { preview?: boolean }
function M.finish(plan, opts)
	opts = opts or {}
	M.done()

	if opts.preview == false then
		plan:apply()
		return
	end
	vim.schedule(function()
		require("features.refactor.preview").open(plan, function()
			plan:apply()
		end)
	end)
end

return M
