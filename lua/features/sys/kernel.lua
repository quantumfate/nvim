--- Working inside a Linux kernel tree: the checks maintainers run, Kconfig lookup,
--- and booting the kernel you just built under QEMU with gdb attached.
---
--- Everything here keys off the tree's own scripts rather than reimplementing them:
--- checkpatch.pl and get_maintainer.pl are what a patch is judged by.
---@class sys.kernel
local M = {}

M.titles = { maintainers = "get_maintainer" }

local output = require("features.lang.output")

--- The kernel tree containing `buf`, or nil.
---@param buf integer
---@return string?
function M.tree(buf)
	local dir = require("lib.root").detectors.pattern(buf, "MAINTAINERS")[1]
	if dir and vim.uv.fs_stat(vim.fs.joinpath(dir, "Kbuild")) then
		return dir
	end
	return nil
end

---@param buf integer
---@return string?
local function require_tree(buf)
	local dir = M.tree(buf)
	if not dir then
		Snacks.notify.warn("Not inside a kernel tree (no MAINTAINERS + Kbuild above this file)", { title = "Kernel" })
	end
	return dir
end

--- Parses `checkpatch.pl --terse` output into quickfix items.
---@param lines string[]
---@param dir string Tree root, since checkpatch prints paths relative to it
---@return table[]
function M.parse_checkpatch(lines, dir)
	local items = {}
	for _, line in ipairs(lines) do
		-- `--show-types` prints `WARNING:TYPE: msg`, without it `WARNING: msg`.
		local file, lnum, kind, msg = line:match("^(%S+):(%d+): (%u+):%s*(.*)$")
		if file then
			if file:sub(1, 1) ~= "/" then
				file = vim.fs.joinpath(dir, file)
			end
			table.insert(items, {
				filename = file,
				lnum = tonumber(lnum),
				text = msg,
				type = kind == "ERROR" and "E" or kind == "WARNING" and "W" or "I",
			})
		end
	end
	return items
end

--- checkpatch.pl on the current file, into the quickfix list.
---@param buf integer
function M.checkpatch(buf)
	local dir = require_tree(buf)
	if not dir then
		return
	end
	local script = vim.fs.joinpath(dir, "scripts", "checkpatch.pl")
	local path = vim.api.nvim_buf_get_name(buf)
	require("features.sys.util").chain("checkpatch", {
		{ cmd = { "perl", script, "--terse", "--no-tree", "--show-types", "--file", path }, cwd = dir },
	}, function(results)
		local items = M.parse_checkpatch(vim.split(results[1].stdout or "", "\n", { plain = true }), dir)
		vim.fn.setqflist({}, " ", { title = "checkpatch " .. vim.fs.basename(path), items = items })
		if #items == 0 then
			Snacks.notify.info("checkpatch: clean", { title = "Kernel" })
		else
			require("features.workspace").dock().open("quickfix")
		end
	end)
end

--- Who to send a patch for this file to.
---@param buf integer
function M.maintainers(buf)
	local dir = require_tree(buf)
	if not dir then
		return
	end
	output.run({
		cmd = { "perl", vim.fs.joinpath(dir, "scripts", "get_maintainer.pl"), "-f", vim.api.nvim_buf_get_name(buf) },
		title = M.titles.maintainers,
		cwd = dir,
		mode = "float",
		link = false,
	})
end

--- The Kconfig symbol under the cursor: `CONFIG_SMP` in C, `SMP` in a Kconfig file.
---@return string?
function M.symbol_at_cursor()
	local word = vim.fn.expand("<cword>")
	word = word:gsub("^CONFIG_", "")
	return word:match("^[%u%d_]+$") and word or nil
end

--- Jumps to where a Kconfig symbol is defined; several definitions go to quickfix.
---@param buf integer
function M.kconfig(buf)
	local dir = require_tree(buf)
	local symbol = M.symbol_at_cursor()
	if not dir or not symbol then
		if dir then
			Snacks.notify.warn("No Kconfig symbol under the cursor", { title = "Kernel" })
		end
		return
	end
	local res = vim.system({
		"rg",
		"--no-heading",
		"--line-number",
		"--glob",
		"Kconfig*",
		"-e",
		"^\\s*(menu)?config\\s+" .. symbol .. "\\s*$",
		dir,
	}, { text = true }):wait()
	local items = {}
	for _, line in ipairs(vim.split(res.stdout or "", "\n", { trimempty = true })) do
		local file, lnum, text = line:match("^(.-):(%d+):(.*)$")
		if file then
			table.insert(items, { filename = file, lnum = tonumber(lnum), text = vim.trim(text) })
		end
	end
	if #items == 0 then
		Snacks.notify.warn("No Kconfig definition for " .. symbol, { title = "Kernel" })
	elseif #items == 1 then
		vim.cmd.edit(vim.fn.fnameescape(items[1].filename))
		vim.api.nvim_win_set_cursor(0, { items[1].lnum, 0 })
	else
		vim.fn.setqflist({}, " ", { title = "Kconfig " .. symbol, items = items })
		require("features.workspace").dock().open("quickfix")
	end
end

--- The QEMU command line for a tree's freshly built kernel, halted and waiting for gdb.
---
--- `nokaslr` so vmlinux's addresses are the running kernel's addresses, which is what
--- makes breakpoints land. `-s -S`: gdbstub on :1234, CPU stopped before the first
--- instruction.
---@param dir string
---@param opts? { initrd?: string, arch?: string }
---@return string[]? cmd, string? missing
function M.qemu_cmd(dir, opts)
	opts = opts or {}
	local image = vim.fs.joinpath(dir, "arch", "x86", "boot", "bzImage")
	if not vim.uv.fs_stat(image) then
		return nil, image
	end
	local cmd = {
		"qemu-system-x86_64",
		"-kernel",
		image,
		"-append",
		"console=ttyS0 nokaslr panic=-1",
		"-nographic",
		"-no-reboot",
		"-m",
		"1G",
		"-smp",
		"2",
		"-s",
		"-S",
	}
	if vim.fn.filereadable("/dev/kvm") == 1 then
		table.insert(cmd, "-enable-kvm")
	end
	if opts.initrd then
		vim.list_extend(cmd, { "-initrd", opts.initrd })
	end
	return cmd
end

--- Boots the tree's kernel under QEMU in a terminal, halted for gdb.
---@param buf integer
---@param initrd? string
function M.qemu(buf, initrd)
	local dir = require_tree(buf)
	if not dir then
		return
	end
	local cmd, missing = M.qemu_cmd(dir, { initrd = initrd })
	if not cmd then
		Snacks.notify.warn("No kernel image at " .. missing .. "; run `make` first", { title = "Kernel" })
		return
	end
	output.terminal(cmd, dir, { title = "qemu" })
	Snacks.notify.info("QEMU halted at reset; <leader>xa attaches gdb", { title = "Kernel" })
end

--- Attaches gdb (DAP) to QEMU's gdbstub with the tree's vmlinux for symbols.
---@param buf integer
function M.attach(buf)
	local dir = M.tree(buf) or vim.uv.cwd()
	local vmlinux = vim.fs.joinpath(dir, "vmlinux")
	if not vim.uv.fs_stat(vmlinux) then
		vmlinux = vim.fn.input("Symbols (vmlinux): ", dir .. "/", "file")
	end
	require("dap").run({
		type = "gdb",
		name = "QEMU gdbstub",
		request = "attach",
		target = "localhost:1234",
		program = vmlinux,
		cwd = dir,
	})
end

return M
