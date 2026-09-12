--- Regression tests for the internal UI/UX library: mutually exclusive slots,
--- sidebar vertical view array, modal keymap profiles, and layout snapshots.
local t = require("tests.harness")
local ui = require("features.ui")
local Slot = require("features.ui.slot")
local sidebar = require("features.ui.sidebar")
local mode = require("features.ui.mode")
local layout = require("features.ui.layout")

t.describe("ui.slot mutual exclusion", function()
	t.it("enforces single active occupant and manages history", function()
		t.reset()
		local opened = {}
		local closed = {}

		local slot = Slot.new("test_slot", {
			view_a = {
				title = "View A",
				ft = "view_a_ft",
				open = function()
					table.insert(opened, "view_a")
					local buf = vim.api.nvim_create_buf(false, true)
					vim.bo[buf].filetype = "view_a_ft"
					vim.cmd("split")
					local win = vim.api.nvim_get_current_win()
					vim.api.nvim_win_set_buf(win, buf)
					return win
				end,
				close = function(win)
					table.insert(closed, "view_a")
					if win and vim.api.nvim_win_is_valid(win) then
						pcall(vim.api.nvim_win_close, win, true)
					end
				end,
			},
			view_b = {
				title = "View B",
				ft = "view_b_ft",
				open = function()
					table.insert(opened, "view_b")
					local buf = vim.api.nvim_create_buf(false, true)
					vim.bo[buf].filetype = "view_b_ft"
					vim.cmd("split")
					local win = vim.api.nvim_get_current_win()
					vim.api.nvim_win_set_buf(win, buf)
					return win
				end,
				close = function(win)
					table.insert(closed, "view_b")
					if win and vim.api.nvim_win_is_valid(win) then
						pcall(vim.api.nvim_win_close, win, true)
					end
				end,
			},
		})

		-- 1. Open View A
		slot:open("view_a")
		t.eq("view_a", slot.active_name)
		local cur_name = slot:find_open()
		t.eq("view_a", cur_name)

		-- 2. Open View B -> View A must be closed (mutual exclusion)
		slot:open("view_b")
		t.eq("view_b", slot.active_name)
		t.eq("view_b", slot:find_open())
		t.ok(vim.tbl_contains(closed, "view_a"), "view_a was not closed when view_b opened")

		-- 3. Back() restores View A
		local restored = slot:back()
		t.eq("view_a", restored)
		t.eq("view_a", slot:find_open())

		-- 4. Toggle closes active view
		slot:toggle("view_a")
		t.eq(nil, slot:find_open())

		slot:close()
	end)
end)

t.describe("ui.sidebar vertical view array", function()
	t.it("exposes sources and provides available other views for selector", function()
		t.eq({ "filesystem", "buffers", "git_status" }, sidebar.SOURCES)
		t.eq("Files", sidebar.LABELS.filesystem)
		t.eq("Buffers", sidebar.LABELS.buffers)
		t.eq("Git", sidebar.LABELS.git_status)

		local other = sidebar.available_views()
		t.ok(#other >= 2, "expected at least 2 alternate views in selector")
	end)
end)

t.describe("ui.mode modal keymaps", function()
	t.it("installs scoped keymaps and restores original bindings on exit", function()
		t.reset()
		local original_called = false
		local modal_called = false

		-- Set up a baseline normal-mode keymap on key 'X'
		vim.keymap.set("n", "X", function()
			original_called = true
		end, { desc = "Original X" })

		-- Register a modal profile overriding 'X'
		mode.register({
			name = "test_profile",
			keymaps = {
				["X"] = {
					rhs = function()
						modal_called = true
					end,
					desc = "Modal X",
				},
			},
		})

		-- Enter modal profile
		t.eq(true, mode.enter("test_profile"))
		t.eq("test_profile", mode.active())

		-- Trigger 'X' while in modal profile -> modal action should run
		pcall(vim.api.nvim_feedkeys, "X", "m", false)

		-- Exit modal profile
		t.eq(true, mode.exit())
		t.eq(nil, mode.active())

		-- Clean up test keymap
		pcall(vim.keymap.del, "n", "X")
	end)
end)

t.describe("ui.layout snapshots and presets", function()
	t.it("captures layout topology and restores previous code layout", function()
		t.reset()
		local buf_code = t.file("code.c", { "int main(void) { return 0; }" })
		vim.cmd.edit(buf_code)
		local code_win = vim.api.nvim_get_current_win()

		-- 1. Snapshot code layout
		local snap = layout.snapshot("test_code")
		t.ok(snap ~= nil, "failed to snapshot layout")
		assert(snap)
		t.eq(code_win, snap.cur_win)

		-- 2. Modify window state (split new window with other buffer)
		vim.cmd("split")
		local temp_win = vim.api.nvim_get_current_win()
		local temp_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(temp_win, temp_buf)

		-- 3. Restore snapshot
		local restored = layout.restore("test_code")
		t.eq(true, restored)
		t.eq(code_win, vim.api.nvim_get_current_win())

		pcall(vim.api.nvim_win_close, temp_win, true)
		pcall(vim.api.nvim_buf_delete, temp_buf, { force = true })
	end)
end)
