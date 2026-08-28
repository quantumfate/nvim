--- `:ToolchainDashboard`: the store rendered as a float, with update actions.
---@class toolchain.dashboard
local M = {}

local registry = require("toolchain.registry")
local store = require("toolchain.store")
local notify = require("toolchain.notify")

local BAR = 16

---@class toolchain.dashboard.State
---@field buf integer
---@field win integer
---@field lines string[]
---@field marks { line: integer, col: integer, end_col: integer, hl: string }[]
---@field eco_at table<integer, string> Ecosystem owning each line, for the cursor actions
local state = nil

local KIND_ICON = { lsp = "󰒋 ", fmt = "󰉼 ", lint = "󱉶 ", dap = "󰃤 ", tool = "󰏫 " }

---@param text string
---@param spans? { from: integer, to: integer, hl: string }[] 0-indexed byte columns
---@param eco? string
local function push(text, spans, eco)
	table.insert(state.lines, text)
	local line = #state.lines - 1
	for _, span in ipairs(spans or {}) do
		table.insert(state.marks, { line = line, col = span.from, end_col = span.to, hl = span.hl })
	end
	if eco then
		state.eco_at[line] = eco
	end
end

---@param present integer
---@param total integer
---@return string bar, string hl
local function bar(present, total)
	if total == 0 then
		return string.rep("░", BAR), "Comment"
	end
	local filled = math.floor((present / total) * BAR + 0.5)
	local hl = present == total and "DiagnosticOk" or (present == 0 and "DiagnosticError" or "DiagnosticWarn")
	return string.rep("█", filled) .. string.rep("░", BAR - filled), hl
end

---@param path string?
---@return string
local function short_path(path)
	if not path then
		return ""
	end
	if path:find("/usr/bin/", 1, true) == 1 then
		return ""
	end
	return (path:gsub("^" .. vim.pesc(vim.uv.os_homedir()), "~"))
end

---@param limit integer
---@return table[]
local function recent_events(limit)
	local ok, lines = pcall(vim.fn.readfile, notify.log_path())
	if not ok then
		return {}
	end
	local out = {}
	for i = #lines, math.max(#lines - limit + 1, 1), -1 do
		local decoded, event = pcall(vim.json.decode, lines[i])
		if decoded then
			table.insert(out, event)
		end
	end
	return out
end

---@param doc table
local function render(doc)
	state.lines, state.marks, state.eco_at = {}, {}, {}

	local summary = doc.summary
	local head = (" toolchain   %d/%d tools present"):format(summary.present, summary.total)
	push(head, { { from = 1, to = 12, hl = "Title" } })
	push(
		("  store %s · written %s"):format(short_path(doc.store), doc.generated_at),
		{ { from = 0, to = -1, hl = "Comment" } }
	)
	push("")

	for _, eco_name in ipairs(registry.ordered()) do
		local eco = doc.ecosystems[eco_name]
		if eco and #eco.tools > 0 then
			local glyph, hl = bar(eco.present, eco.present + eco.missing)
			local header = ("  %-10s %s %d/%d"):format(eco_name, glyph, eco.present, eco.present + eco.missing)
			push(header, {
				{ from = 2, to = 12, hl = "Function" },
				{ from = 13, to = 13 + #glyph, hl = hl },
			}, eco_name)

			for _, tool in ipairs(eco.tools) do
				local icon = KIND_ICON[tool.kind] or "  "
				local mark = tool.present and "✓" or (tool.optional and "·" or "✗")
				local mark_hl = tool.present and "DiagnosticOk" or (tool.optional and "Comment" or "DiagnosticError")
				local version = tool.version or (tool.present and "" or (tool.package or "unpackaged"))
				-- The column is fixed width; a chatty --version must not wrap the row.
				if #version > 34 then
					version = version:sub(1, 31) .. "..."
				end
				local line = ("    %s %s %-22s %-34s %s"):format(icon, mark, tool.name, version, short_path(tool.path))
				push(line, {
					{ from = 4 + #icon + 1, to = 4 + #icon + 1 + #mark, hl = mark_hl },
					{ from = 4 + #icon + 3 + 22, to = -1, hl = "Comment" },
				}, eco_name)
			end
			push("")
		end
	end

	local events = recent_events(5)
	if #events > 0 then
		push("  recent events", { { from = 0, to = -1, hl = "Title" } })
		for _, event in ipairs(events) do
			local ok = event.status == "ok"
			local line = ("    %s %-18s %-10s %s"):format(
				ok and "✓" or "✗",
				event.tool or event.phase,
				event.source or "",
				(event.detail or ""):sub(1, 48)
			)
			push(line, {
				{ from = 4, to = 5, hl = ok and "DiagnosticOk" or "DiagnosticError" },
				{ from = 24, to = -1, hl = "Comment" },
			})
		end
		push("")
	end

	push("  u update all · U update ecosystem · r refresh · e events · q close", {
		{ from = 0, to = -1, hl = "Comment" },
	})
end

local function paint()
	local ns = vim.api.nvim_create_namespace("toolchain_dashboard")
	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, state.lines)
	vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
	for _, mark in ipairs(state.marks) do
		pcall(vim.api.nvim_buf_set_extmark, state.buf, ns, mark.line, mark.col, {
			end_col = mark.end_col == -1 and #state.lines[mark.line + 1] or mark.end_col,
			hl_group = mark.hl,
		})
	end
	vim.bo[state.buf].modifiable = false
end

---@param refresh? boolean Re-probe PATH first
function M.reload(refresh)
	if not (state and vim.api.nvim_win_is_valid(state.win)) then
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(state.win)
	local function draw(doc)
		render(doc)
		paint()
		pcall(vim.api.nvim_win_set_cursor, state.win, { math.min(cursor[1], #state.lines), cursor[2] })
	end
	if refresh then
		store.refresh({}, draw)
	else
		draw(store.read() or {})
	end
end

---@return string?
local function eco_under_cursor()
	return state.eco_at[vim.api.nvim_win_get_cursor(state.win)[1] - 1]
end

function M.open()
	local doc = store.read()
	if not doc then
		store.refresh({}, function()
			M.open()
		end)
		return
	end

	state = { buf = vim.api.nvim_create_buf(false, true), lines = {}, marks = {}, eco_at = {} }
	render(doc)

	local width = math.min(96, vim.o.columns - 4)
	local height = math.min(#state.lines + 1, vim.o.lines - 6)
	state.win = vim.api.nvim_open_win(state.buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "single",
		title = " toolchain ",
		title_pos = "center",
	})
	vim.wo[state.win].cursorline = true
	vim.bo[state.buf].filetype = "toolchain"
	paint()

	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = state.buf, nowait = true, desc = desc })
	end

	map("q", function()
		vim.api.nvim_win_close(state.win, true)
	end, "Close")
	map("<esc>", function()
		vim.api.nvim_win_close(state.win, true)
	end, "Close")
	map("r", function()
		M.reload(true)
	end, "Refresh the store")
	map("e", function()
		vim.api.nvim_win_close(state.win, true)
		vim.cmd.edit(notify.log_path())
	end, "Open the event log")
	map("u", function()
		require("toolchain.update").run({ on_finish = M.reload })
	end, "Update everything")
	map("U", function()
		local eco = eco_under_cursor()
		if eco then
			require("toolchain.update").run({ ecosystems = { eco }, plugins = false, on_finish = M.reload })
		end
	end, "Update the ecosystem under the cursor")
end

return M
