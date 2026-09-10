--- Autocommand definitions.
---
--- Written as direct `nvim_create_autocmd` calls rather than a table plus a driver
--- loop: nothing else consumes the definitions, so the table only replayed the API
--- one entry at a time while hiding which events were actually registered.

--- Declared once here; `clear = true` makes re-sourcing this file idempotent.
local general = vim.api.nvim_create_augroup("general_settings", { clear = true })
local mappings = vim.api.nvim_create_augroup("buffer_mappings", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
	group = general,
	desc = "Highlight text on yank",
	callback = function()
		vim.hl.on_yank({ higroup = "Search", timeout = 100 })
	end,
})

-- Transient, non-file windows: `q` closes them and they stay out of :ls.
vim.api.nvim_create_autocmd("FileType", {
	group = mappings,
	pattern = {
		"qf",
		"help",
		"man",
		"lspinfo",
		"checkhealth",
		"notify",
		"query",
		"dbout",
		-- Read-only pickers and reports that otherwise need <Esc> and leave you
		-- guessing which key closes what.
		"crash",
		"refactor-preview",
		-- Docked in an edgy panel, trouble's own `q` does not always survive the
		-- panel's keymaps.
		"trouble",
		"dap-float",
		"lspsagaoutline",
		"tsplayground",
		"neotest-output",
		"neotest-summary",
	},
	desc = "Close transient windows with q",
	callback = function(ev)
		vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, nowait = true })
		vim.bo[ev.buf].buflisted = false
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = mappings,
	pattern = { "dap-view", "dap-view-term", "dap-repl" }, -- dap-repl is set by nvim-dap
	desc = "Close the whole dap panel group with q",
	callback = function(ev)
		vim.keymap.set("n", "q", function()
			require("features.workspace").dock().close()
		end, { buffer = ev.buf, nowait = true })
	end,
})

-- User events other specs lazy-load on (nvim-lint listens for FileOpened). Each
-- fires once, then deletes its own group so the check stops costing anything.
-- Taken from AstroNvim.
vim.api.nvim_create_autocmd("BufEnter", {
	group = vim.api.nvim_create_augroup("dir_opened", { clear = true }),
	nested = true,
	desc = "Fire User DirOpened on the first directory buffer",
	callback = function(args)
		local name = vim.api.nvim_buf_get_name(args.buf)
		local stat = name ~= "" and vim.uv.fs_stat(name) or nil
		if stat and stat.type == "directory" then
			vim.api.nvim_del_augroup_by_name("dir_opened")
			vim.api.nvim_exec_autocmds("User", { pattern = "DirOpened" })
			vim.api.nvim_exec_autocmds(args.event, { buffer = args.buf, data = args.data })
		end
	end,
})

vim.api.nvim_create_autocmd({ "BufRead", "BufWinEnter", "BufNewFile" }, {
	group = vim.api.nvim_create_augroup("file_opened", { clear = true }),
	nested = true,
	desc = "Fire User FileOpened on the first real file buffer",
	callback = function(args)
		if vim.bo[args.buf].buftype == "" and vim.api.nvim_buf_get_name(args.buf) ~= "" then
			vim.api.nvim_del_augroup_by_name("file_opened")
			vim.api.nvim_exec_autocmds("User", { pattern = "FileOpened" })
		end
	end,
})
