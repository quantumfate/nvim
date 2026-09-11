--- Shows what a plan would do, before it does it.
---
--- The engine already computed every edit by the time it was about to apply them, so
--- this costs nothing extra — it renders the plan it was handed and applies it only
--- if asked.
---@class refactor.preview
local M = {}

local ns = vim.api.nvim_create_namespace("refactor_preview")

--- Applies a plan's edits to a copy of the buffer's lines, without touching it.
---@param bufnr integer
---@param edits lsp.TextEdit[]
---@return string[] lines
local function simulate(bufnr, edits)
	local scratch = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(scratch, 0, -1, false, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
	vim.lsp.util.apply_text_edits(edits, scratch, "utf-8")
	local lines = vim.api.nvim_buf_get_lines(scratch, 0, -1, false)
	vim.api.nvim_buf_delete(scratch, { force = true })
	return lines
end

--- Line numbers in `after` that a real diff calls changed.
---
--- Not a positional compare: inserting one line makes every later line differ from
--- the line that now shares its number, so a positional compare reports the whole
--- rest of the file as changed. `vim.diff` returns hunks, which is the actual answer.
---@param before string[]
---@param after string[]
---@return table<integer, boolean>
local function changed_lines(before, after)
	local changed = {}
	local hunks = vim.text.diff(table.concat(before, "\n") .. "\n", table.concat(after, "\n") .. "\n", {
		result_type = "indices",
		algorithm = "histogram",
	})
	for _, hunk in ipairs(hunks or {}) do
		-- { start_a, count_a, start_b, count_b }; b is the "after" side.
		local start, count = hunk[3], hunk[4]
		if count == 0 then
			-- A pure deletion has no line in `after`; mark where it was removed from.
			changed[math.max(start, 1)] = true
		end
		for i = start, start + count - 1 do
			changed[i] = true
		end
	end
	return changed
end

---@class refactor.PreviewLine
---@field text string
---@field hl? string Whole-line highlight
---@field gutter? string Two-column marker before the text, e.g. "+ "
---@field gutter_hl? string
---@field lnum_end? integer Byte column where the line-number prefix ends

--- Renders the plan as a list of display lines.
---@param plan refactor.Plan
---@return refactor.PreviewLine[], table<integer, {bufnr: integer, lnum: integer}>
local function render(plan)
	local out, jumps = {}, {}
	---@param text string
	---@param hl? string
	---@param extra? table
	local function add(text, hl, extra)
		table.insert(out, vim.tbl_extend("force", { text = text, hl = hl }, extra or {}))
		return #out
	end

	local files, edits = plan:size()
	add(("%s — %d edit(s) in %d file(s)"):format(plan.title, edits, files), "RefactorPreviewTitle")

	for _, section in ipairs({
		{ key = "conflicts", label = "Conflicts — these block apply", hl = "RefactorPreviewConflict", mark = "✖ " },
		{ key = "skips", label = "Left alone", hl = "RefactorPreviewSkip", mark = "▲ " },
	}) do
		local entries = plan[section.key]
		if #entries > 0 then
			add("")
			add(section.label, section.hl)
			for _, entry in ipairs(entries) do
				local row = add(
					("  %s:%d  %s"):format(vim.fn.fnamemodify(entry.filename, ":~:."), entry.lnum, entry.text),
					nil,
					{ gutter = section.mark, gutter_hl = section.hl }
				)
				-- Conflicts are the actionable half of a plan: the thing you have to go
				-- and fix before the refactoring can run. They were the one kind of line
				-- you could not jump to.
				jumps[row] = { filename = entry.filename, lnum = entry.lnum, conflict = section.key == "conflicts" }
			end
		end
	end

	-- What was not verified matters as much as what was: an empty conflict list is
	-- only reassuring if the checks actually ran.
	local guards = vim.tbl_keys(plan.unchecked)
	if #guards > 0 then
		table.sort(guards)
		add("")
		add("Not checked", "RefactorPreviewUnchecked")
		for _, guard in ipairs(guards) do
			add(
				("  %s — %s"):format(guard, plan.unchecked[guard]),
				nil,
				{ gutter = "? ", gutter_hl = "RefactorPreviewUnchecked" }
			)
		end
	end

	for bufnr, buf_edits in pairs(plan.edits) do
		local before = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local after = simulate(bufnr, buf_edits)
		local changed = changed_lines(before, after)

		add("")
		add(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":~:."), "RefactorPreviewFile")

		-- Only the changed lines plus a line of context, so a wide refactoring stays
		-- readable instead of reprinting whole files.
		local shown = {}
		for lnum in pairs(changed) do
			for i = lnum - 1, lnum + 1 do
				shown[i] = true
			end
		end
		local ordered = vim.tbl_keys(shown)
		table.sort(ordered)

		local previous
		for _, lnum in ipairs(ordered) do
			if previous and lnum > previous + 1 then
				add("   ⋮", "RefactorPreviewElision")
			end
			local line = after[lnum]
			if line then
				-- A gutter marker as well as a background: the change is then visible
				-- without relying on a colour difference the eye has to hunt for.
				local prefix = ("%4d "):format(lnum)
				local row = add(("  %s%s"):format(prefix, line), changed[lnum] and "RefactorPreviewAdded" or nil, {
					gutter = changed[lnum] and "+ " or "  ",
					gutter_hl = changed[lnum] and "RefactorPreviewAddedSign" or nil,
					lnum_end = 2 + #prefix,
				})
				jumps[row] = { bufnr = bufnr, lnum = lnum }
			end
			previous = lnum
		end
	end

	add("")
	local hint = #plan.conflicts > 0 and " <CR> apply    q abort    <Tab> jump to the conflict "
		or " <CR> apply    q abort    <Tab> jump to line under cursor "
	add(hint, "RefactorPreviewHelp")
	return out, jumps
end

--- Opens the preview. `on_apply` runs when the user confirms.
---@param plan refactor.Plan
---@param on_apply fun()
function M.open(plan, on_apply)
	local lines, jumps = render(plan)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(
		buf,
		0,
		-1,
		false,
		vim.tbl_map(function(l)
			return l.text
		end, lines)
	)

	for i, line in ipairs(lines) do
		if line.hl then
			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { end_row = i, hl_group = line.hl, hl_eol = true })
		end
		if line.gutter then
			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				sign_text = line.gutter,
				sign_hl_group = line.gutter_hl,
			})
		end
		-- The line number is scaffolding, not content; it should not compete with the
		-- code beside it.
		if line.lnum_end then
			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				end_col = math.min(line.lnum_end, #line.text),
				hl_group = "RefactorPreviewLnum",
			})
		end
	end
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "refactor-preview"
	vim.b[buf].lang_output = true

	local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.7))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = math.floor(vim.o.columns * 0.8),
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor(vim.o.columns * 0.1),
		style = "minimal",
		border = "rounded",
		title = " " .. plan.title .. " ",
		title_pos = "center",
	})
	vim.wo[win].signcolumn = "yes:2"
	vim.wo[win].cursorline = true
	vim.wo[win].winhighlight = "Normal:LangOutput,NormalFloat:LangOutput,FloatBorder:LangOutputBorder"

	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	--- Jumps to the entry under the cursor, or to the first conflict when the cursor is
	--- on a line that goes nowhere.
	---
	--- Falling back to the first conflict is the useful default: a blocked plan is one
	--- you have to go and fix, and hunting for the line it named is the work the preview
	--- was supposed to save.
	local function jump()
		local target = jumps[vim.api.nvim_win_get_cursor(win)[1]]
		if not target then
			local rows = vim.tbl_keys(jumps)
			table.sort(rows)
			for _, row in ipairs(rows) do
				if jumps[row].conflict then
					target = jumps[row]
					break
				end
			end
		end
		if not target then
			Snacks.notify.info("Nothing to jump to on this line", { title = "Refactor" })
			return
		end

		close()
		if target.filename then
			vim.cmd.edit(vim.fn.fnameescape(target.filename))
		elseif target.bufnr and vim.api.nvim_buf_is_valid(target.bufnr) then
			vim.api.nvim_set_current_buf(target.bufnr)
		end
		pcall(vim.api.nvim_win_set_cursor, 0, { target.lnum, 0 })
		vim.cmd("normal! zz")
	end

	local blocked = #plan.conflicts > 0

	-- Ops that ask for a name arrive here from inside `vim.ui.input`, and the Enter
	-- that submitted the prompt is still pending. Without this the window opens and
	-- immediately applies a refactoring nobody looked at.
	--
	-- Armed on SafeState, which fires when nvim is idle waiting for input — that is
	-- exactly "the pending key has been consumed". A timer would either be too short
	-- on a slow machine or swallow a fast, deliberate Enter.
	local armed = false
	vim.api.nvim_create_autocmd("SafeState", {
		once = true,
		callback = function()
			armed = true
		end,
	})

	vim.keymap.set("n", "<CR>", function()
		if not armed then
			return
		end
		if blocked then
			Snacks.notify.error("Resolve the conflicts first", { title = "Refactor" })
			return
		end
		close()
		on_apply()
	end, { buffer = buf, nowait = true, desc = "Apply refactoring" })

	for _, key in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", key, close, { buffer = buf, nowait = true, desc = "Abort refactoring" })
	end

	for _, key in ipairs({ "<Tab>", "gf" }) do
		vim.keymap.set("n", key, jump, { buffer = buf, nowait = true, desc = "Jump to this line" })
	end
end

return M
