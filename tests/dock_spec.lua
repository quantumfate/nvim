--- Regression tests for the bottom slot.
---
--- The dock exists because six things wanted the bottom edge and edgy stacked all of
--- them. It holds exactly one: the same key puts it away, a different key swaps to it.
local t = require("tests.harness")
local dock = require("features.workspace.dock")

--- A view whose open and close are ordinary window operations, so these tests do not
--- depend on trouble, snacks or nvim-dap being loadable headlessly.
---@param name string
local function fake_view(name)
	local ft = "dockspec-" .. name
	return {
		title = name,
		ft = ft,
		open = function()
			vim.cmd("botright split")
			local buf = vim.api.nvim_create_buf(false, true)
			vim.bo[buf].filetype = ft
			vim.api.nvim_win_set_buf(0, buf)
		end,
		close = function()
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_is_valid(win) and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == ft then
					pcall(vim.api.nvim_win_close, win, true)
				end
			end
		end,
	}
end

---@return string[]
local function open_views()
	local found = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
		if ft:match("^dockspec%-") then
			-- Parenthesised: gsub returns the string *and* a count, and table.insert
			-- would read the count as a position.
			table.insert(found, (ft:gsub("^dockspec%-", "")))
		end
	end
	table.sort(found)
	return found
end

t.describe("dock", function()
	local saved

	local function with_fakes(fn)
		saved = dock.views
		dock.views = { alpha = fake_view("alpha"), beta = fake_view("beta") }
		local ok, err = pcall(fn)
		dock.close()
		dock.views = saved
		if not ok then
			error(err, 0)
		end
	end

	t.it("holds one view at a time", function()
		t.reset()
		with_fakes(function()
			dock.open("alpha")
			t.eq({ "alpha" }, open_views())

			-- The whole point: a different key swaps rather than stacking.
			dock.open("beta")
			t.eq({ "beta" }, open_views(), "opening a second view did not put the first away")
		end)
	end)

	t.it("the same key closes it", function()
		t.reset()
		with_fakes(function()
			dock.toggle("alpha")
			t.eq({ "alpha" }, open_views())
			dock.toggle("alpha")
			t.eq({}, open_views(), "toggling the open view did not close it")
		end)
	end)

	t.it("a different key swaps instead of closing", function()
		t.reset()
		with_fakes(function()
			dock.toggle("alpha")
			dock.toggle("beta")
			t.eq({ "beta" }, open_views(), "toggling a different view should swap, not close")
		end)
	end)

	t.it("back() returns to the previous view", function()
		t.reset()
		with_fakes(function()
			dock.toggle("alpha")
			dock.toggle("beta")
			dock.back()
			t.eq({ "alpha" }, open_views(), "back did not restore the previous occupant")
		end)
	end)

	t.it("a view closed by hand does not block reopening", function()
		-- Same stale-state class as everywhere else: `q` closes the panel, nothing tells
		-- the dock, and the next press toggles off something that is not there.
		t.reset()
		with_fakes(function()
			dock.toggle("alpha")
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "dockspec-alpha" then
					pcall(vim.api.nvim_win_close, win, true)
				end
			end
			t.eq({}, open_views())
			t.eq(nil, dock.current(), "a closed view still reads as the occupant")

			dock.toggle("alpha")
			t.eq({ "alpha" }, open_views(), "reopening after an external close was refused")
		end)
	end)

	t.it("every real view names a command for both directions", function()
		for name, view in pairs(saved or dock.views) do
			t.ok(view.open, name .. " has no open")
			t.ok(view.close, name .. " has no close")
			t.ok(view.ft, name .. " has no filetype, so it cannot be detected")
			t.ok(view.title, name .. " has no title for the statusline")
		end
	end)
end)
