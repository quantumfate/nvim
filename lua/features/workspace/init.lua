--- A layout with named slots, so things appear where you expect them.
---
--- The problem is not that windows are hard to open — it is that every tool opens its
--- own, in its own place, and you end up looking for things. navbuddy takes the whole
--- screen and hides the code it is describing; an assembly view adds a split that
--- shifts everything along; a REPL lands wherever the last one did.
---
--- So the layout is declared once and tools are given a slot:
---
---     ┌──────┬───────────────┬───────────────┬─────────┐
---     │ tree │     main      │      aux      │ outline │
---     └──────┴───────────────┴───────────────┴─────────┘
---     ├──────────────────  dock  ───────────────────────┤
---
--- `main` and `aux` are ordinary editor windows; the rest are edges that toggle.
---
--- What makes it predictable is **borrowing**: a transient view does not create a
--- window, it takes over `aux` and gives it back. Assembly appears where the second
--- file was, and closing it puts the file back with the cursor where it was.
---@class workspace
local M = {}

---@alias workspace.Slot "tree"|"main"|"aux"|"outline"|"dock"

---@class workspace.Loan
---@field buf integer Buffer displaced by the borrow
---@field view table Cursor and scroll of that buffer
---@field released boolean

--- Outstanding loans per slot, innermost last, so nested borrows unwind in order.
---@type table<string, workspace.Loan[]>
local loans = {}

----------------------------------------------------------------------------------
-- Slot identity
----------------------------------------------------------------------------------

--- Windows are tagged rather than found by position: a window keeps its identity when
--- you move or resize it, and a layout guessed from geometry does not.
---@param win integer
---@param slot workspace.Slot
local function tag(win, slot)
	if vim.api.nvim_win_is_valid(win) then
		vim.w[win].workspace_slot = slot
	end
end

--- The window currently holding a slot.
---
--- `dock` is not tagged this way: its occupant is an edgy panel that edgy creates and
--- destroys, so "what is in the dock" is a question for workspace/dock.lua rather than
--- a window tag that would go stale.
---@param slot workspace.Slot
---@return integer? win
function M.win(slot)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) and vim.w[win].workspace_slot == slot then
			return win
		end
	end
	return nil
end

--- True for a window holding a real file, rather than a panel, a float, or one of the
--- renderings from features/lang.
---@param win integer
---@return boolean
function M.is_editor(win)
	if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= "" then
		return false
	end
	local buf = vim.api.nvim_win_get_buf(win)
	return vim.bo[buf].buftype == "" and not vim.b[buf].lang_output
end

--- The editor window the cursor is in, else any editor window.
---@return integer? win
function M.current_editor()
	local win = vim.api.nvim_get_current_win()
	if M.is_editor(win) then
		return win
	end
	for _, candidate in ipairs(vim.api.nvim_list_wins()) do
		if M.is_editor(candidate) then
			return candidate
		end
	end
	return nil
end

--- The primary editor window. Everything else is positioned relative to it.
---@return integer? win
function M.main()
	local win = M.win("main")
	if win and M.is_editor(win) then
		return win
	end
	local editor = M.current_editor()
	if editor then
		tag(editor, "main")
		return editor
	end
	return nil
end

--- The secondary editor window, created if it does not exist.
---@param opts? { create?: boolean }
---@return integer? win
function M.aux(opts)
	opts = opts or {}
	local win = M.win("aux")
	if win and vim.api.nvim_win_is_valid(win) and M.is_editor(win) then
		return win
	end
	-- A stale tag points at a window that is gone or is no longer an editor; the
	-- screen is the authority.
	if win then
		vim.w[win].workspace_slot = nil
	end

	local main = M.main()

	-- A second editor window that nothing has claimed is adopted, rather than adding a
	-- third one beside it.
	for _, candidate in ipairs(vim.api.nvim_list_wins()) do
		if M.is_editor(candidate) and candidate ~= main and vim.w[candidate].workspace_slot == nil then
			tag(candidate, "aux")
			return candidate
		end
	end

	if opts.create == false or not main then
		return nil
	end

	-- nvim_open_win with `split`, never `:vsplit`: the command form fires a layout pass
	-- that edgy runs under a textlock, and the buffer swap after it fails with E788.
	local created = vim.api.nvim_open_win(vim.api.nvim_win_get_buf(main), false, { split = "right", win = main })
	tag(created, "aux")
	vim.w[created].workspace_created = true
	return created
end

--- Editor windows, left to right.
---
--- Position, not tag order. Tags drift — a pane gets closed, a borrow is abandoned, a
--- plugin opens a window — and once they have drifted, "main" and "aux" stop meaning
--- what you see, so `<leader>wa` lands somewhere different each time. Sorting by column
--- makes the answer whatever is actually on screen.
---@return integer[]
local function editors_by_position()
	local wins = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if M.is_editor(win) then
			table.insert(wins, win)
		end
	end
	table.sort(wins, function(a, b)
		local ca, cb = vim.api.nvim_win_get_position(a)[2], vim.api.nvim_win_get_position(b)[2]
		if ca == cb then
			return vim.api.nvim_win_get_position(a)[1] < vim.api.nvim_win_get_position(b)[1]
		end
		return ca < cb
	end)
	return wins
end

--- Panes that take content width: editors and the renderings beside them, left to
--- right. Not the tree, the outline or the dock — those are edges, and edgy sizes them.
---
--- Counting only editors was wrong: with `main.c | main.c | c asm` the editor count is
--- two, nothing gets closed, and three panes share the width.
---@return integer[]
local function content_by_position()
	-- Only the top row. A window below the editors is a dock occupant — a terminal, the
	-- debugger, a crash report — and closing one of those to satisfy a *horizontal*
	-- limit is how pressing Enter on a crash frame ended up wiping the screen.
	local top = math.huge
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_config(win).relative == "" then
			top = math.min(top, vim.api.nvim_win_get_position(win)[1])
		end
	end

	local wins = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local floating = vim.api.nvim_win_get_config(win).relative ~= ""
		local on_top_row = vim.api.nvim_win_get_position(win)[1] == top
		if not floating and on_top_row and (M.is_editor(win) or vim.b[buf].lang_output) then
			table.insert(wins, win)
		end
	end
	table.sort(wins, function(a, b)
		local ca, cb = vim.api.nvim_win_get_position(a)[2], vim.api.nvim_win_get_position(b)[2]
		if ca == cb then
			return vim.api.nvim_win_get_position(a)[1] < vim.api.nvim_win_get_position(b)[1]
		end
		return ca < cb
	end)
	return wins
end

--- Closes content panes beyond the first two.
---
--- Two panes is the whole shape: one file and one other thing. A third appears the
--- moment something opens a split without asking — neo-tree does exactly that when the
--- pane it would have used is pinned — and every pane after that is width taken from
--- the two you were reading. Closing a window does not touch its buffer: the file stays
--- loaded and one `:b` away.
---
--- Duplicates go first. Two panes showing the same file is the common case and the
--- easiest one to lose nothing by closing.
---@return integer closed
function M.enforce_two()
	local wins = content_by_position()
	if #wins <= 2 then
		return 0
	end

	local current = vim.api.nvim_get_current_win()
	local closed = 0

	--- Closes `win` unless it is the one the cursor is in.
	---@param win integer
	---@return boolean
	local function drop(win)
		if win == current or not vim.api.nvim_win_is_valid(win) then
			return false
		end
		if pcall(vim.api.nvim_win_close, win, false) then
			closed = closed + 1
			return true
		end
		return false
	end

	local seen = {}
	for _, win in ipairs(wins) do
		local buf = vim.api.nvim_win_get_buf(win)
		if seen[buf] and #content_by_position() > 2 then
			drop(win)
		else
			seen[buf] = true
		end
	end

	-- Still too many: trim from the left, which is the oldest, keeping the cursor's
	-- pane and any rendering — the rendering is what was just asked for.
	local remaining = content_by_position()
	for _, win in ipairs(remaining) do
		if #content_by_position() <= 2 then
			break
		end
		if not vim.b[vim.api.nvim_win_get_buf(win)].lang_output then
			drop(win)
		end
	end

	return closed
end

----------------------------------------------------------------------------------
-- Borrowing
----------------------------------------------------------------------------------

--- The editor pane that is not `win`, created if there is only one.
---@param win integer
---@return integer? other
function M.other(win)
	M.enforce_two()
	M.retag()

	for _, candidate in ipairs(editors_by_position()) do
		if candidate ~= win then
			return candidate
		end
	end

	local created = vim.api.nvim_open_win(vim.api.nvim_win_get_buf(win), false, { split = "right", win = win })
	vim.w[created].workspace_created = true
	M.retag()
	return created
end

--- The pane a lower-level view belongs in: always the right one.
---
--- Direction carries meaning here. Source is the thing you are writing and assembly is
--- what it became, so source reads left and output reads right — the same way you read
--- a compiler pipeline. "The pane that is not yours" is not good enough: stand in the
--- right-hand pane and it hands back the left one, and the assembly ends up on the side
--- your eye expects the source.
---
--- When the source is already on the right, the two swap: the source moves left,
--- taking its cursor and scroll with it, and the freed right pane is the target.
---@param source_win integer
---@return integer? target, integer? source_now Where the source ended up
---@return boolean? created True when the target pane had to be made
function M.lower(source_win)
	M.enforce_two()
	M.retag()

	local wins = editors_by_position()
	if #wins < 2 then
		local created =
			vim.api.nvim_open_win(vim.api.nvim_win_get_buf(source_win), false, { split = "right", win = source_win })
		vim.w[created].workspace_created = true
		M.retag()
		return created, source_win, true
	end

	local left, right = wins[1], wins[2]
	if source_win ~= right then
		return right, source_win
	end

	-- The source is on the right. The two panes swap: the source moves left with its
	-- cursor, and what was on the left moves right — where the borrow will displace it
	-- and, on release, give it back. Moving the source alone would leave the right pane
	-- still holding the source, so releasing would show the same file twice and lose
	-- the other one entirely.
	local source_buf = vim.api.nvim_win_get_buf(right)
	local other_buf = vim.api.nvim_win_get_buf(left)
	local source_view = vim.api.nvim_win_call(right, function()
		return vim.fn.winsaveview()
	end)
	local other_view = vim.api.nvim_win_call(left, function()
		return vim.fn.winsaveview()
	end)

	local function set(win_id, target_buf)
		local pinned = vim.wo[win_id].winfixbuf
		vim.wo[win_id].winfixbuf = false
		local ok = pcall(vim.api.nvim_win_set_buf, win_id, target_buf)
		vim.wo[win_id].winfixbuf = pinned
		return ok
	end

	if not set(left, source_buf) then
		-- Could not move it; better a view on the wrong side than none at all.
		return right, source_win
	end
	set(right, other_buf)

	vim.api.nvim_win_call(left, function()
		vim.fn.winrestview(source_view)
	end)
	vim.api.nvim_win_call(right, function()
		vim.fn.winrestview(other_view)
	end)
	-- Follow the file rather than the window: the cursor was in the source, and the
	-- source is now on the left.
	vim.api.nvim_set_current_win(left)
	M.retag()
	return right, left
end

--- Lends `aux` to a buffer, remembering what it displaced.
---
--- `transient` decides how it comes back. A symbol picker is done the moment you leave
--- it, so it releases itself. A linked view is not: reading assembly means moving
--- between the source and the output constantly, and a view that vanished when you
--- looked away would be useless — those wait for `q`.
---@param buf integer
---@param opts? { focus?: boolean, transient?: boolean, on_release?: fun(), from?: integer, lower?: boolean }
--- `lower` puts the view in the right-hand pane, moving the source left if it is
--- sitting there — for renderings that read as "below" the source.
---@return fun() release, integer? win The pane it was lent, so callers do not have to
--- ask for it again — asking twice can split twice.
function M.borrow(buf, opts)
	opts = opts or {}
	local win, created
	if opts.from and opts.lower then
		win, _, created = M.lower(opts.from)
	elseif opts.from then
		local existed = M.win("aux") ~= nil
		win = M.other(opts.from)
		created = not existed
	else
		local existed = M.win("aux") ~= nil
		win = M.aux()
		created = not existed
	end
	if not win then
		-- Nowhere to put it, but the caller still gets a release so it needs no special
		-- case for the failure.
		return function() end, nil
	end

	local previous = vim.api.nvim_win_get_buf(win)
	local view = vim.api.nvim_win_call(win, function()
		return vim.fn.winsaveview()
	end)
	local was_pinned = vim.wo[win].winfixbuf

	loans.aux = loans.aux or {}
	local loan = { buf = previous, view = view, released = false }
	table.insert(loans.aux, loan)

	vim.wo[win].winfixbuf = false
	vim.api.nvim_win_set_buf(win, buf)
	vim.w[win].workspace_borrowed = true
	if opts.focus ~= false then
		vim.api.nvim_set_current_win(win)
	end

	local function release()
		if loan.released then
			return
		end
		loan.released = true
		for i, entry in ipairs(loans.aux or {}) do
			if entry == loan then
				table.remove(loans.aux, i)
				break
			end
		end

		if vim.api.nvim_win_is_valid(win) then
			vim.w[win].workspace_borrowed = #(loans.aux or {}) > 0 or nil

			-- A pane this borrow created has nothing to give back: restoring the buffer
			-- it was seeded with leaves a second copy of the file you were already
			-- reading, in a pane you never asked for.
			if created and #(loans.aux or {}) == 0 then
				pcall(vim.api.nvim_win_close, win, false)
				if opts.on_release then
					opts.on_release()
				end
				return
			end

			if vim.api.nvim_buf_is_valid(loan.buf) then
				-- A borrowed view pins itself with `winfixbuf` so nothing wanders into
				-- the pane while it is there. Giving the pane back is the one buffer
				-- switch that must be allowed, so the pin comes off first.
				local pinned = vim.wo[win].winfixbuf
				vim.wo[win].winfixbuf = false
				local ok, err = pcall(vim.api.nvim_win_set_buf, win, loan.buf)
				if ok then
					vim.api.nvim_win_call(win, function()
						vim.fn.winrestview(loan.view)
					end)
				else
					vim.wo[win].winfixbuf = pinned
					Snacks.notify.warn("Could not restore the pane: " .. tostring(err), { title = "Workspace" })
					return
				end
				vim.wo[win].winfixbuf = was_pinned
			end
		end
		if opts.on_release then
			opts.on_release()
		end
	end

	-- `q` always gives the slot back, whatever the view is.
	vim.keymap.set("n", "q", release, { buffer = buf, nowait = true, desc = "Return the pane" })

	if opts.transient then
		vim.api.nvim_create_autocmd("WinLeave", {
			once = true,
			callback = function()
				vim.schedule(release)
			end,
		})
	end

	return release, win
end

--- Forgets every outstanding loan without restoring anything.
---
--- For tests, and for the rare case where a loan outlives the window it was taken
--- against. A stale loan makes the *next* release think it is not the last one, so the
--- pane it created is never closed.
function M.forget_loans()
	loans.aux = {}
end

--- Whether `aux` is currently lent out.
---@return boolean
function M.borrowed()
	return #(loans.aux or {}) > 0
end

----------------------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------------------

--- Re-derives every slot from what is on screen. Cheap, and idempotent.
function M.retag()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.w[win].workspace_slot == "main" or vim.w[win].workspace_slot == "aux" then
			vim.w[win].workspace_slot = nil
		end
	end
	local wins = editors_by_position()
	if wins[1] then
		tag(wins[1], "main")
	end
	if wins[2] then
		tag(wins[2], "aux")
	end
end

--- Collapses to a single editor pane, with the edges closed.
---
--- Panes the *user* opened are left alone. Only the outline, the dock and a second pane
--- this module created are taken down; tearing down a split someone deliberately made
--- and then re-opening a different one is the behaviour that made this key feel random.
function M.collapse()
	local current = M.current_editor()
	for _, win in ipairs(content_by_position()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local ours = vim.w[win].workspace_created or vim.b[buf].lang_output
		if win ~= current and ours and vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, false)
		end
	end
	M.outline(false)
	M.dock().close()
	M.retag()
	vim.cmd("wincmd =")
end

--- Whether the layout is currently expanded.
---
--- Derived, never remembered: the outline can be closed with `q`, a pane with `:q`, and
--- a cached flag then says "expanded" while the screen says otherwise — so the next
--- press collapses nothing and the key looks broken.
---@return boolean
function M.expanded()
	return #content_by_position() > 1 or M.win("outline") ~= nil
end

--- Toggles between the working layout and a single pane.
---
--- Every binding that opens something should close it again with the same key: there
--- and back, rather than one-way and then hunting for how to undo it.
function M.toggle_layout()
	if M.expanded() then
		M.collapse()
	else
		M.layout()
	end
end

--- Puts the workspace into its canonical shape: two editor windows side by side, with
--- the outline on the right.
---
--- Idempotent on purpose. Running it twice gives the same layout, not a third pane,
--- because the slots are re-derived from the screen first.
function M.layout()
	M.enforce_two()
	M.retag()
	local main = M.main()
	if not main then
		Snacks.notify.warn("No editor window to build a layout around", { title = "Workspace" })
		return
	end
	M.aux()
	M.retag()
	M.outline(true)
	vim.api.nvim_set_current_win(M.win("main") or main)
	-- Equalise after the edges have settled; edgy re-lays the screen when the outline
	-- appears, and sizing before that leaves the editor panes lopsided.
	M.equalize()
end

--- Gives every window an even share, once the edges have finished moving.
function M.equalize()
	vim.schedule(function()
		pcall(vim.cmd, "wincmd =")
		local ok, editor = pcall(require, "edgy.editor")
		if ok and editor.equalize then
			pcall(editor.equalize)
		end
	end)
end

--- Toggles the outline. Trouble already follows the active buffer, so "follows the
--- window your cursor is in" comes free once there is exactly one of them.
---@param state? boolean true opens, false closes, nil toggles
function M.outline(state)
	local ok = pcall(require, "trouble")
	if not ok then
		Snacks.notify.warn("trouble.nvim is not available", { title = "Workspace" })
		return
	end
	if state == true then
		vim.cmd("Trouble symbols open focus=false")
	elseif state == false then
		pcall(vim.cmd, "Trouble symbols close")
	else
		vim.cmd("Trouble symbols toggle focus=false")
	end
end

--- The bottom slot. One occupant at a time; see workspace/dock.lua.
---@return workspace.dock
function M.dock()
	return require("features.workspace.dock")
end

--- Sends the cursor to a slot, creating it if that is what the slot means.
---@param slot workspace.Slot
function M.focus(slot)
	if slot == "main" or slot == "aux" then
		M.retag()
	end
	local win = slot == "aux" and M.aux() or M.win(slot)
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_set_current_win(win)
	else
		Snacks.notify.info(("No %s window open"):format(slot), { title = "Workspace" })
	end
end

--- What the layout currently looks like, for `:WorkspaceInfo`.
---@return string[]
function M.report()
	M.retag()
	local lines = {}
	for _, slot in ipairs({ "tree", "main", "aux", "outline", "dock" }) do
		local win = M.win(slot)
		local where = "—"
		if win and vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			local name = vim.api.nvim_buf_get_name(buf)
			where = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or ("[" .. vim.bo[buf].filetype .. "]")
		end
		table.insert(lines, ("  %-8s %s"):format(slot, where))
	end
	table.insert(lines, M.borrowed() and ("  aux is lent out (%d deep)"):format(#loans.aux) or "  aux is free")
	table.insert(lines, "  dock: " .. (M.dock().current() or "empty"))
	return lines
end

--- Registers the commands, keymaps and the tagging autocmds.
function M.setup()
	local group = vim.api.nvim_create_augroup("workspace", { clear = true })

	-- Tag on entry so a window the user made by hand still gets an identity, and the
	-- layout is whatever is actually on screen rather than whatever we last built.
	-- Re-derive on entering an editor window rather than naming whatever is new.
	-- Tagging on sight meant a third split, a preview window or a returning borrow
	-- could take the "aux" name and leave the real one unnamed.
	-- Tagging only writes window variables, which is safe under a textlock; anything
	-- that opens, closes or re-buffers a window is scheduled instead.
	vim.api.nvim_create_autocmd("WinEnter", {
		group = group,
		callback = function()
			if M.is_editor(vim.api.nvim_get_current_win()) then
				M.retag()
			end
		end,
	})

	-- A file landing beside a rendering is put right, because that is the case the
	-- limit exists for: neo-tree splits rather than reuse a pinned pane, and you end up
	-- with source, source and assembly sharing the width.
	--
	-- Deliberately narrow. Enforcing on every `BufWinEnter` closed windows the user had
	-- opened on purpose, which is worse than the problem — a third plain split is a
	-- choice, a third split *next to a rendering* is an accident.
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = group,
		callback = function(ev)
			if vim.bo[ev.buf].buftype ~= "" or vim.b[ev.buf].lang_output then
				return
			end
			vim.schedule(function()
				local has_rendering = false
				for _, win in ipairs(content_by_position()) do
					if vim.b[vim.api.nvim_win_get_buf(win)].lang_output then
						has_rendering = true
					end
				end
				if has_rendering and M.enforce_two() > 0 then
					M.retag()
				end
			end)
		end,
	})

	vim.api.nvim_create_user_command("WorkspaceInfo", function()
		vim.notify(table.concat(M.report(), "\n"), vim.log.levels.INFO, { title = "Workspace" })
	end, { desc = "Which window is which slot" })

	-- <leader>w is the window group.
	vim.keymap.set("n", "<leader>wo", function()
		M.outline()
	end, { desc = "Outline" })
	vim.keymap.set("n", "<leader>wz", M.toggle_layout, { desc = "Layout: expand / collapse" })
	vim.keymap.set("n", "<leader>wa", function()
		M.focus("aux")
	end, { desc = "Focus aux pane" })
	vim.keymap.set("n", "<leader>wd", function()
		M.dock().toggle()
	end, { desc = "Toggle dock (last used)" })
	vim.keymap.set("n", "<leader>wb", function()
		M.dock().back()
	end, { desc = "Dock: previous view" })

	vim.keymap.set("n", "<leader>wi", function()
		vim.notify(table.concat(M.report(), "\n"), vim.log.levels.INFO, { title = "Workspace" })
	end, { desc = "Workspace info" })
end

return M
