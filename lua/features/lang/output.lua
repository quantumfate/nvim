--- Running a tool and showing what it printed.
---
--- Preprocessor output, LLVM IR, assembly and AST dumps are all the same shape: run a
--- command against the current file, put the result somewhere readable, keep it out of
--- the way of the source. One implementation so every language's version of "show me
--- what this actually compiles to" behaves identically.
---
--- Windows are created with `nvim_open_win`, never `:vsplit`. The command form fires
--- the whole WinNew/WinEnter/BufEnter chain, and edgy re-runs its layout inside it —
--- which is textlocked, so the buffer swap that follows fails with
--- `E788: Not allowed to edit another buffer now`. Passing the buffer to
--- `nvim_open_win` means there is no swap to fail.
---@class lang.output
local M = {}

---@alias lang.OutputMode "split"|"float"

---@class lang.View
---@field buf integer
---@field win integer?
---@field mode lang.OutputMode
---@field source integer Buffer the output was produced from
---@field release? fun() Returns the aux pane, when this view borrowed it

--- Views this module owns, keyed by title, so re-running a command reuses its window
--- instead of stacking a new one every time.
---@type table<string, lang.View>
local views = {}

--- The view on screen right now. There is only ever one: a different action replaces
--- it, and the same action again closes it. Two half-remembered panes competing for
--- the same corner is the thing this whole module exists to avoid.
---
--- Never read directly — go through `M.showing()`. A window can be closed by `:q`, by
--- `<C-w>c`, by edgy re-laying the screen, or by a plugin that split over it, and none
--- of those tell us. A remembered "still open" then makes the next press close a view
--- that is not there, which reads as the key having stopped working.
---@type string?
local showing = nil

--- Floats read as transient and splits read as permanent, so the default follows what
--- the view is for: a macro expansion is a glance, assembly is something you work
--- beside.
---@type table<string, lang.OutputMode>
local DEFAULT_MODE = {
	["expand"] = "float",
	["preprocessed"] = "float",
	["comptime"] = "float",
	["check"] = "float",
	["syntax"] = "float",
	["ast"] = "float",
}

--- The mode a title defaults to.
---@param title string
---@return lang.OutputMode
local function default_mode(title)
	for key, mode in pairs(DEFAULT_MODE) do
		if title:find(key, 1, true) then
			return mode
		end
	end
	return "split"
end

--- Window options every output view shares.
---@param buf integer
---@param win integer
local function style(buf, win)
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].wrap = false
	vim.wo[win].cursorline = true
	vim.wo[win].winfixbuf = true
	-- No background tint: a border and a title say "this is a rendering" without
	-- dulling every character in it. A split has no border, so lualine's winbar names
	-- it — see the `lang_output` component, which reads `b:lang_output_title`.
	vim.wo[win].winhighlight =
		"Normal:LangOutput,NormalFloat:LangOutput,FloatBorder:LangOutputBorder,WinBar:LangOutputTitle,WinBarNC:LangOutputTitleNC"
	vim.b[buf].lang_output = true
end

--- Creates or reuses the window for a view.
---@param title string
---@param mode lang.OutputMode
---@param buf integer
---@return integer win
local function window_for(title, mode, buf, source)
	local existing = views[title]
	if existing and existing.win and vim.api.nvim_win_is_valid(existing.win) then
		vim.api.nvim_win_set_buf(existing.win, buf)
		return existing.win
	end

	-- Output arrives asynchronously, by which time the cursor may be in a picker, the
	-- dock or the other pane. Anchor on the window showing the source instead.
	local source_win = source and vim.fn.bufwinid(source) or -1
	if source_win == -1 then
		source_win = vim.api.nvim_get_current_win()
	end
	if vim.api.nvim_win_get_config(source_win).relative ~= "" then
		source_win = require("features.workspace").current_editor() or source_win
	end
	local win

	if mode == "float" then
		local width = math.min(math.floor(vim.o.columns * 0.6), 110)
		local height = math.min(math.floor(vim.o.lines * 0.5), 24)
		win = vim.api.nvim_open_win(buf, false, {
			relative = "editor",
			width = width,
			height = height,
			row = math.floor((vim.o.lines - height) / 2),
			col = math.floor((vim.o.columns - width) / 2),
			style = "minimal",
			border = "rounded",
			title = " " .. title .. " ",
			title_pos = "center",
			zindex = 60,
		})
	else
		-- Borrow the pane opposite the source, rather than adding a window. A split
		-- would shift everything along and leave you hunting for where the output went;
		-- this puts it where the other file already was, and gives it back on `q`.
		--
		-- Always the right pane, never merely "the other one". Source is what you
		-- wrote and this is what it became, so source reads left and output reads
		-- right; standing in the right-hand pane used to flip that.
		local workspace = require("features.workspace")
		views[title] = views[title] or {}
		local release, lent = workspace.borrow(buf, { focus = false, from = source_win, lower = true })
		views[title].release = release
		win = lent or source_win
	end

	style(buf, win)
	return win
end

--- Keeps the output's cursor in step with the source, when the tool told us which
--- source line each output line came from.
---
--- Only useful where the mapping exists: assembly and IR carry `.loc` directives and
--- `!dbg` metadata. Everything else has no line correspondence to follow.
---@param view lang.View
---@param map table<integer, integer> output row -> source line
local function link_cursor(view, map)
	if vim.tbl_isempty(map) then
		return
	end

	-- The reverse direction too, so moving in the source highlights the instructions
	-- it produced.
	local reverse = {}
	for out_row, src_line in pairs(map) do
		reverse[src_line] = reverse[src_line] or out_row
	end

	local group = vim.api.nvim_create_augroup("lang_output_link_" .. view.buf, { clear = true })
	local ns = vim.api.nvim_create_namespace("lang_output_link_" .. view.buf)
	local syncing = false

	--- Moves `win` to `line` without letting the move trigger the other direction.
	---@param win integer
	---@param line integer
	local function move(win, line)
		if syncing or not vim.api.nvim_win_is_valid(win) then
			return
		end
		syncing = true
		local count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
		pcall(vim.api.nvim_win_set_cursor, win, { math.min(line, count), 0 })
		vim.api.nvim_win_call(win, function()
			vim.cmd("normal! zz")
		end)
		syncing = false
	end

	vim.api.nvim_create_autocmd("CursorMoved", {
		group = group,
		buffer = view.buf,
		callback = function()
			local row = vim.api.nvim_win_get_cursor(0)[1]
			local line = map[row]
			if line then
				local src_win = vim.fn.bufwinid(view.source)
				if src_win ~= -1 then
					move(src_win, line)
				end
			end
		end,
	})

	vim.api.nvim_create_autocmd("CursorMoved", {
		group = group,
		buffer = view.source,
		callback = function()
			if not (view.win and vim.api.nvim_win_is_valid(view.win)) then
				return
			end
			local line = vim.api.nvim_win_get_cursor(0)[1]
			-- Highlight every output row this source line produced, then jump to the
			-- first: one statement usually becomes several instructions.
			vim.api.nvim_buf_clear_namespace(view.buf, ns, 0, -1)
			local first
			for out_row, src_line in pairs(map) do
				if src_line == line then
					first = math.min(first or out_row, out_row)
					pcall(vim.api.nvim_buf_set_extmark, view.buf, ns, out_row - 1, 0, {
						line_hl_group = "LangOutputLinked",
					})
				end
			end
			if first then
				move(view.win, first)
			end
		end,
	})

	-- `<CR>` crosses between the two, the cursor already synced on both sides. In the
	-- source it only does that while this view is on screen; otherwise it is the
	-- ordinary `<CR>`, so a closed view leaves nothing behind that behaves oddly.
	vim.keymap.set("n", "<CR>", function()
		local src_win = vim.fn.bufwinid(view.source)
		if src_win ~= -1 then
			vim.api.nvim_set_current_win(src_win)
		end
	end, { buffer = view.buf, nowait = true, desc = "Back to the source" })

	-- An edited source makes the map wrong line by line. Better no link than a cursor
	-- that confidently lands on the wrong statement.
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		buffer = view.source,
		once = true,
		callback = function()
			vim.schedule(function()
				pcall(vim.api.nvim_del_augroup_by_id, group)
				if vim.api.nvim_buf_is_valid(view.buf) then
					vim.api.nvim_buf_clear_namespace(view.buf, ns, 0, -1)
				end
				Snacks.notify.info("Source edited: the line link is off until the view is re-run", { title = "Output" })
			end)
		end,
	})

	vim.keymap.set("n", "<CR>", function()
		-- The view buffer is reused per title, so it may now show another file's output.
		local current = view.win
			and vim.api.nvim_win_is_valid(view.win)
			and vim.api.nvim_win_get_buf(view.win) == view.buf
			and vim.b[view.buf].lang_output_source == view.source
		if current then
			vim.schedule(function()
				if vim.api.nvim_win_is_valid(view.win) then
					vim.api.nvim_set_current_win(view.win)
				end
			end)
			return ""
		end
		return "<CR>"
	end, { buffer = view.source, expr = true, desc = "Into the linked view" })
end

--- Maps output rows to source lines, from the line markers compilers emit.
---
--- gas writes `.loc <file> <line>`, and LLVM IR carries `!dbg !N` pointing at a
--- `!DILocation(line: N)`. Both say "everything after me came from this line", so the
--- mapping is a running assignment rather than a lookup.
---@param lines string[]
---@return table<integer, integer>
local function line_map(lines)
	local map = {}

	-- LLVM: resolve !dbg references through the metadata table at the end.
	local dilocation = {}
	for _, line in ipairs(lines) do
		local id, num = line:match("^!(%d+)%s*=%s*!DILocation%(line:%s*(%d+)")
		if id then
			dilocation[id] = tonumber(num)
		end
	end

	local current
	for row, line in ipairs(lines) do
		local loc = line:match("^%s*%.loc%s+%d+%s+(%d+)")
		if loc then
			current = tonumber(loc)
		else
			local dbg = line:match("!dbg%s+!(%d+)")
			if dbg and dilocation[dbg] then
				current = dilocation[dbg]
			end
		end
		if current and line:match("%S") then
			map[row] = current
		end
	end
	return map
end

--- Drops the remembered view when its window is gone, so the record matches reality.
---@return string? title The view that is genuinely on screen
local function reconcile()
	if not showing then
		return nil
	end
	local view = views[showing]
	local alive = view
		and view.win
		and vim.api.nvim_win_is_valid(view.win)
		and vim.api.nvim_win_get_buf(view.win) == view.buf
	if not alive then
		if view then
			view.win = nil
			view.release = nil
		end
		showing = nil
	end
	return showing
end

--- Closes whatever is on screen, giving back a borrowed pane if that is what it is.
---@param title? string Only close if this is what is showing
---@return boolean closed
function M.close(title)
	local name = reconcile()
	if not name or (title and title ~= name) then
		return false
	end
	local view = views[name]
	showing = nil
	if not view then
		return false
	end
	if view.release then
		view.release()
		view.release = nil
	elseif view.win and vim.api.nvim_win_is_valid(view.win) then
		pcall(vim.api.nvim_win_close, view.win, true)
	end
	view.win = nil
	return true
end

--- True when `title` is the view currently on screen. Reconciles first, so a window
--- closed behind our back is noticed rather than believed.
---@param title string
---@return boolean
function M.showing(title)
	return reconcile() == title
end

--- Releases the borrow when a view's window is closed by anything other than us.
--- Without this, closing the pane with `:q` leaves the loan outstanding and the file
--- it displaced is never given back.
function M.setup()
	vim.api.nvim_create_autocmd("WinClosed", {
		group = vim.api.nvim_create_augroup("lang_output_reconcile", { clear = true }),
		callback = function(ev)
			local closed = tonumber(ev.match)
			local view = showing and views[showing]
			if not (view and view.win == closed) then
				return
			end

			-- The record is corrected now, so nothing reads a stale "still open".
			local release = view.release
			view.release = nil
			view.win = nil
			showing = nil

			-- The windows are touched later. `WinClosed` runs under a textlock, and
			-- giving a pane back means setting a buffer in a window — which fails with
			-- `E788: Not allowed to edit another buffer now`, and takes edgy's layout
			-- pass down with it.
			if release then
				vim.schedule(release)
			end
		end,
	})
end

--- Drops every remembered view. For tests, and for recovering from a state nothing
--- else noticed.
function M.forget()
	showing = nil
	views = {}
end

--- Renders lines into the view for `title`.
---@param opts { title: string, lines: string[], filetype?: string, mode?: lang.OutputMode, source: integer, link?: boolean, map?: table<integer, integer> }
function M.show(opts)
	local title = opts.title
	local mode = opts.mode or default_mode(title)

	-- Whatever was there makes way, so the pane never becomes a stack.
	local current = reconcile()
	if current and current ~= title then
		M.close(current)
	end

	local existing = views[title]
	local buf = (existing and vim.api.nvim_buf_is_valid(existing.buf)) and existing.buf
		or vim.api.nvim_create_buf(false, true)

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.b[buf].lang_output = true
	vim.b[buf].lang_output_title = title
	vim.b[buf].lang_output_source = opts.source

	if opts.filetype and opts.filetype ~= "" then
		vim.bo[buf].filetype = opts.filetype
	end

	local win = window_for(title, mode, buf, opts.source)
	local release = views[title] and views[title].release
	local view = { buf = buf, win = win, mode = mode, source = opts.source, release = release }
	views[title] = view

	-- `q` gives the pane back when it was borrowed, and closes the window when it was
	-- ours to begin with. Same key either way.
	vim.keymap.set("n", "q", function()
		M.close(title)
	end, { buffer = buf, nowait = true, desc = "Close" })

	if opts.link ~= false then
		-- A map supplied by the transform beats one recovered from the text: the
		-- transform saw the markers before they were filtered out.
		link_cursor(view, opts.map or line_map(opts.lines))
	end

	showing = title

	-- A float is read and dismissed, so it takes focus and `q` lands where you expect.
	-- A split is worked beside, so focus stays in the source and the cursor link works.
	if mode == "float" then
		vim.api.nvim_set_current_win(win)
		for _, key in ipairs({ "q", "<Esc>" }) do
			vim.keymap.set("n", key, function()
				M.close(title)
			end, { buffer = buf, nowait = true, desc = "Close" })
		end
	end

	pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
	return view
end

--- Runs `cmd` and shows stdout.
---
--- stderr is shown too when the command fails: a preprocessor or compiler that refuses
--- is telling you something, and hiding it to keep the pane tidy would be exactly the
--- wrong call in the one case you needed the output.
--- `stderr = true` is for tools that write their real output there (Go's `-S` and `-m`).
---@param opts { cmd: string[], title: string, filetype?: string, cwd?: string, artifact?: string, mode?: lang.OutputMode, link?: boolean, stderr?: boolean, on_lines?: fun(lines: string[]): string[], table<integer, integer>? }
function M.run(opts)
	local title = opts.title
	local source = vim.api.nvim_get_current_buf()

	-- One at a time per view. Two `<leader>va` presses during a nine-second zig build
	-- used to start two compiles; the second replaced the first when it landed, so
	-- nothing broke but half the work was wasted and the spinner made no sense.
	local jobs = require("features.lang.jobs")
	if jobs.running(title) then
		Snacks.notify.info(title .. " is already running", { title = title })
		return
	end

	-- The statusline carries "this is running", so the notification does not have to.
	-- A toast per invocation was noise for the fast ones and gone before you read it
	-- on the slow ones.
	local finished = jobs.start(title, opts.cmd[1])

	-- vim.system throws when the program does not exist. Unguarded, the job was
	-- registered but never finished: a spinner forever and "already running" on retry.
	local ok, err = pcall(vim.system, opts.cmd, { text = true, cwd = opts.cwd }, function(res)
		vim.schedule(function()
			finished()
			local text = res.stdout or ""
			if opts.stderr then
				text = (res.stderr or "") .. "\n" .. text
			end
			if opts.artifact and res.code == 0 then
				local ok, content = pcall(vim.fn.readfile, opts.artifact)
				text = ok and table.concat(content, "\n") or ""
			end
			if opts.artifact then
				pcall(vim.fn.delete, opts.artifact)
			end
			if res.code ~= 0 and not opts.stderr then
				text = (res.stderr or "") .. "\n" .. text
			end

			local lines = vim.split(vim.trim(text), "\n", { plain = true })
			local map
			if opts.on_lines then
				lines, map = opts.on_lines(lines)
			end
			if #lines == 0 or (#lines == 1 and lines[1] == "") then
				Snacks.notify.warn("No output", { title = title })
				return
			end

			M.show({
				title = title,
				lines = lines,
				filetype = res.code == 0 and opts.filetype or nil,
				mode = opts.mode,
				source = source,
				link = opts.link,
				map = map,
			})

			if res.code ~= 0 then
				Snacks.notify.warn(("%s exited %d; stderr shown"):format(opts.cmd[1], res.code), { title = title })
			end
		end)
	end)
	if not ok then
		finished()
		Snacks.notify.error(("%s could not start: %s"):format(opts.cmd[1], tostring(err)), { title = title })
	end
end

--- Runs a build-style command in a terminal, rooted at the project.
---
--- `auto_close = false` because snacks closes the window when the process exits, and a
--- program that prints three lines and returns is exactly the case where that means you
--- never see them. Insert mode stays on so anything that reads stdin still works.
---@param cmd string[]
---@param cwd string
---@param opts? { title?: string }
function M.terminal(cmd, cwd, opts)
	opts = opts or {}
	Snacks.terminal(cmd, {
		cwd = cwd,
		auto_close = false,
		win = {
			style = "terminal",
			border = "rounded",
			title = " " .. (opts.title or table.concat(cmd, " ")) .. " ",
			title_pos = "center",
			wo = {
				-- Terminal keeps the editor background too; only the border is coloured.
				winhighlight = "Normal:LangOutput,NormalFloat:LangOutput,FloatBorder:LangOutputBorder",
			},
		},
	})
end

--- A throwaway path for tools that insist on writing to a file.
---@param suffix string
---@return string
function M.tempfile(suffix)
	return vim.fn.tempname() .. suffix
end

--- Assembler directives that carry no instruction information.
---
--- Every backend buries the code under these. Zig emits one `.file` per module in the
--- standard library — hundreds of lines before the first instruction — and clang adds
--- unwind tables and line markers. Stripping them is the difference between reading the
--- output and scrolling past it. Symbol boundaries are kept, because knowing which
--- function you are looking at is the point, and so is `.loc`, which is what the cursor
--- link is built from.
---@type table<string, boolean>
local KEEP = {
	[".globl"] = true,
	[".global"] = true,
	[".type"] = true,
	[".size"] = true,
	[".section"] = true,
	[".weak"] = true,
	[".local"] = true,
	[".comm"] = true,
	[".intel_syntax"] = true,
}

--- Keeps only the symbols with an instruction from this file, symbol to symbol.
---
--- `cargo rustc --emit asm` covers the whole crate plus monomorphised std, and between
--- the functions sit data symbols (`GCC_except_table4:`, `DW.ref.rust_eh_personality:`)
--- whose directives were already stripped. Counting only instructions is what drops
--- those: a label or a `.size` can inherit a line mapping, but it produced no code.
--- A symbol's `.section`/`.type` header comes before its label, so the directives after
--- a block's last instruction belong to the next block and move with it.
---@param out string[]
---@param map table<integer, integer>
---@return string[] kept, table<integer, integer> map
local function source_functions(out, map)
	local kept, kept_map = {}, {}
	local block, block_map, has = {}, {}, false

	local function flush(carry_header)
		local last = #block
		if carry_header then
			local function is_header(l)
				return l:match("^%s*$") or (l:match("^%s+%.") and not l:match("^%s*%.size"))
			end
			while last > 0 and is_header(block[last]) do
				last = last - 1
			end
		end
		if has then
			for i = 1, last do
				table.insert(kept, block[i])
				kept_map[#kept] = block_map[i]
			end
		end
		local header, header_map = {}, {}
		for i = last + 1, #block do
			table.insert(header, block[i])
			header_map[#header] = block_map[i]
		end
		block, block_map, has = header, header_map, false
	end

	for row, l in ipairs(out) do
		-- A symbol starts a block; a local branch label (`.LBB0_1:`) is inside one.
		if l:match("^[%w_%.%$]+:%s*$") and not l:match("^%.L") then
			flush(true)
		end
		table.insert(block, l)
		block_map[#block] = map[row]
		-- Indented and not a directive: an instruction.
		if map[row] and l:match("^%s+[^%.%s]") then
			has = true
		end
	end
	flush(false)
	return kept, kept_map
end

--- Drops directive noise from assembly output, keeping instructions and symbols.
---
--- `.loc` is consumed rather than kept: it is the line mapping the cursor link needs,
--- but showing it would put a directive between every pair of instructions. So it is
--- read on the way past and dropped, and the map it produces indexes the lines that
--- actually survive.
---@param lines string[]
---@return string[] kept, table<integer, integer> map
function M.strip_asm(lines, source, opts)
	local out, map = {}, {}
	local current
	local in_debug = false
	-- `.file N "dir" "name"`: which file each `.loc` number means. Inlined code from a
	-- header or from Rust's core carries other files' line numbers, which must not
	-- move the cursor around this buffer.
	local files = {}
	local want = source and vim.fs.basename(source)

	for _, line in ipairs(lines) do
		local file_id, a, b = line:match('^%s*%.file%s+(%d+)%s+"([^"]*)"%s*"?([^"]*)')
		if file_id then
			files[file_id] = (b ~= "" and b) or a
		end
		local loc_file, loc = line:match("^%s*%.loc%s+(%d+)%s+(%d+)")
		if loc then
			local named = files[loc_file]
			current = (not want or not named or vim.fs.basename(named) == want) and tonumber(loc) or nil
		else
			local directive, rest = line:match("^%s*(%.[%w_]+)%s*(.*)$")

			-- Debug info is the price of the `.loc` markers the cursor link is built
			-- from, and it is the last thing you want to read: DWARF sections run to
			-- hundreds of lines of string tables. Everything from a `.debug_*` section
			-- until the next real one is dropped.
			if directive == ".section" then
				in_debug = rest:match("^%s*%.debug") ~= nil
			end

			-- A new symbol has no line until its first `.loc`; the previous function's
			-- last one would otherwise map the data symbols that follow it.
			if not directive and line:match("^[%w_%$][%w_%.%$]*:%s*$") then
				current = nil
			end

			-- `.LBB0_1:` reads as a directive but is a jump target: dropping it while
			-- keeping the `je .LBB0_1` that needs it leaves the jump pointing nowhere.
			local label = line:match("^%s*%.L[%w_%.%$]+:")
			if not in_debug and (not directive or KEEP[directive] or label) then
				table.insert(out, line)
				if current and line:match("%S") then
					map[#out] = current
				end
			end
		end
	end

	if opts and opts.only_source_functions and want then
		local kept, kept_map = source_functions(out, map)
		if #kept > 0 then
			return kept, kept_map
		end
	end
	return out, map
end

--- Back-compatible wrapper for callers that only want the lines.
---@param lines string[]
---@return string[]
function M.strip_asm_noise(lines)
	return (M.strip_asm(lines))
end

--- Keeps only the LLVM function bodies whose names start with `prefix`.
---
--- A Debug-mode IR dump of a two-line Zig file is a third of a million lines, because
--- it contains the whole standard library. The interesting part is the handful of
--- functions from this module. Metadata lines are kept: `!DILocation` is what the
--- cursor link resolves `!dbg` through.
---@param prefix string e.g. "m." for m.zig
---@return fun(lines: string[]): string[]
function M.only_module(prefix)
	return function(lines)
		local out, depth, keeping = {}, 0, false
		local metadata = {}
		for _, line in ipairs(lines) do
			if line:match("^!%d+%s*=%s*!DILocation") then
				table.insert(metadata, line)
			end
			if not keeping then
				local name = line:match("^define[^@]*@([%w_%.]+)")
				if name and name:sub(1, #prefix) == prefix then
					keeping, depth = true, 0
				end
			end
			if keeping then
				table.insert(out, line)
				depth = depth + select(2, line:gsub("{", "")) - select(2, line:gsub("}", ""))
				if depth <= 0 and line:match("^}") then
					keeping = false
					table.insert(out, "")
				end
			end
		end
		if #out == 0 then
			return { ("No functions from `%s` in the output."):format(prefix) }
		end
		return vim.list_extend(out, metadata)
	end
end

--- True when every binary is on PATH; notifies about the first one that is not.
---@param ... string
---@return boolean
function M.require_exe(...)
	for _, exe in ipairs({ ... }) do
		if vim.fn.executable(exe) == 0 then
			Snacks.notify.warn(exe .. " is not installed", { title = "Language" })
			return false
		end
	end
	return true
end

return M
