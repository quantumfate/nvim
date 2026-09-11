--- Systems tools under `<leader>x`: what the binary really contains, how a struct is
--- really laid out, what a crash really says, and the kernel-tree workflow.
---
--- Each tool is a thin reader over the program that already knows the answer —
--- pahole, nm, objdump, addr2line, checkpatch.pl, QEMU, gdb. Nothing is re-derived.
---@class sys
local M = {}

--- Every key, with what it needs, so `:SysInfo` and the README cannot disagree.
---@type { key: string, desc: string, run: fun(buf: integer), needs: string[] }[]
M.keys = {
	{
		key = "l",
		desc = "Struct layout (holes, cache lines)",
		needs = { "pahole" },
		run = function(buf)
			local layout = require("features.sys.layout")
			require("features.sys.util").toggle(layout.title, function()
				layout.show(buf)
			end)
		end,
	},
	{
		key = "e",
		desc = "ELF symbols by size",
		needs = { "nm", "addr2line" },
		run = function(buf)
			local elf = require("features.sys.elf")
			require("features.sys.util").toggle(elf.titles.symbols, function()
				elf.symbols(buf)
			end)
		end,
	},
	{
		key = "d",
		desc = "Disassemble function from the binary",
		needs = { "nm", "objdump" },
		run = function(buf)
			local elf = require("features.sys.elf")
			require("features.sys.util").toggle(elf.titles.disassembly, function()
				elf.function_at_cursor(buf)
			end)
		end,
	},
	{
		key = "r",
		desc = "Run binary, crash frames to quickfix",
		needs = {},
		run = function(buf)
			require("features.sys.run").run(buf)
		end,
	},
	{
		key = "q",
		desc = "Stack trace in buffer to quickfix",
		needs = {},
		run = function(buf)
			require("features.sys.stack").from_buffer(buf)
		end,
	},
	{
		key = "h",
		desc = "Hex view toggle",
		needs = { "xxd" },
		run = function(buf)
			M.hex(buf)
		end,
	},
	{
		key = "k",
		desc = "checkpatch this file",
		needs = { "perl" },
		run = function(buf)
			require("features.sys.kernel").checkpatch(buf)
		end,
	},
	{
		key = "m",
		desc = "Maintainers of this file",
		needs = { "perl" },
		run = function(buf)
			require("features.sys.kernel").maintainers(buf)
		end,
	},
	{
		key = "c",
		desc = "Kconfig definition",
		needs = { "rg" },
		run = function(buf)
			require("features.sys.kernel").kconfig(buf)
		end,
	},
	{
		key = "Q",
		desc = "Boot kernel in QEMU (halted)",
		needs = { "qemu-system-x86_64" },
		run = function(buf)
			require("features.sys.kernel").qemu(buf)
		end,
	},
	{
		key = "a",
		desc = "Attach gdb to QEMU",
		needs = { "gdb" },
		run = function(buf)
			require("features.sys.kernel").attach(buf)
		end,
	},
}

--- Toggles a buffer between bytes and an xxd dump. Written back through `xxd -r`, so
--- editing the dump edits the file.
---@param buf integer
function M.hex(buf)
	if vim.b[buf].sys_hex then
		vim.cmd("silent %!xxd -r")
		vim.bo[buf].filetype = vim.b[buf].sys_hex_ft or ""
		vim.b[buf].sys_hex = nil
	else
		vim.b[buf].sys_hex_ft = vim.bo[buf].filetype
		-- Without 'binary' a trailing newline is added on write and NULs get mangled.
		vim.bo[buf].binary = true
		vim.cmd("silent %!xxd -g1")
		vim.bo[buf].filetype = "xxd"
		vim.b[buf].sys_hex = true
	end
end

--- Registers `<leader>x*` and the commands.
function M.setup()
	for _, spec in ipairs(M.keys) do
		vim.keymap.set("n", "<leader>x" .. spec.key, function()
			spec.run(vim.api.nvim_get_current_buf())
		end, { desc = spec.desc })
	end

	vim.api.nvim_create_user_command("SysTrace", function()
		require("features.sys.stack").from_buffer(vim.api.nvim_get_current_buf())
	end, { desc = "Stack frames in this buffer to quickfix" })

	vim.api.nvim_create_user_command("Qemu", function(args)
		require("features.sys.kernel").qemu(vim.api.nvim_get_current_buf(), args.fargs[1])
	end, { nargs = "?", complete = "file", desc = "Boot the tree's kernel under QEMU: :Qemu [initrd]" })

	vim.api.nvim_create_user_command("SysInfo", function()
		local lines = {}
		for _, spec in ipairs(M.keys) do
			local missing = vim.tbl_filter(function(exe)
				return vim.fn.executable(exe) == 0
			end, spec.needs)
			table.insert(
				lines,
				("<leader>x%s  %-40s %s"):format(spec.key, spec.desc, #missing == 0 and "ok" or ("missing: " .. table.concat(missing, ", ")))
			)
		end
		Snacks.notify.info(table.concat(lines, "\n"), { title = "Systems tools" })
	end, { desc = "Systems tools and what they need" })
end

return M
