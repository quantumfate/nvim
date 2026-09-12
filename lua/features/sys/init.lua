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
		key = "p",
		desc = "Profile: hot lines marked (perf)",
		needs = { "perf" },
		run = function(buf)
			require("features.sys.profile").run(buf)
		end,
	},
	{
		key = "s",
		desc = "Syscalls, failures to source (strace)",
		needs = { "strace", "addr2line" },
		run = function(buf)
			local trace = require("features.sys.trace")
			require("features.sys.util").toggle(trace.title, function()
				trace.run(buf)
			end)
		end,
	},
	{
		key = "f",
		desc = "Annotate function from profile (perf)",
		needs = { "perf", "addr2line" },
		run = function(buf)
			local profile = require("features.sys.profile")
			require("features.sys.util").toggle(profile.annotate_title, function()
				profile.annotate(buf)
			end)
		end,
	},
	{
		key = "b",
		desc = "bpftrace probes on the binary",
		needs = { "bpftrace" },
		run = function(buf)
			require("features.sys.bpf").pick(buf)
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
		key = "S",
		desc = "sparse on this file",
		needs = { "sparse" },
		run = function(buf)
			require("features.sys.semantic").sparse(buf)
		end,
	},
	{
		key = "C",
		desc = "coccinelle report on this file",
		needs = { "spatch" },
		run = function(buf)
			require("features.sys.semantic").cocci(buf)
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
	{
		key = "P",
		desc = "Patch series workflow (b4)",
		needs = { "b4", "git" },
		run = function(buf)
			require("features.sys.patch").pick(buf)
		end,
	},
	{
		key = "R",
		desc = "Record binary with rr",
		needs = { "rr" },
		run = function(buf)
			require("features.sys.run").rr_record(buf)
		end,
	},
}

--- The exact bytes a buffer stands for.
---
--- An unmodified buffer is read from disk: its lines already went through 'fileformat'
--- and 'eol' when it was loaded, so a `\r` or a missing final newline is gone from
--- them. A modified one is rebuilt with those same options.
---@param buf integer
---@return string
local function buffer_bytes(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if not vim.bo[buf].modified and name ~= "" and vim.uv.fs_stat(name) then
		return vim.fn.readblob(name)
	end
	local nl = vim.bo[buf].fileformat == "dos" and "\r\n" or "\n"
	local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), nl)
	if vim.bo[buf].eol or (vim.bo[buf].fixeol and not vim.bo[buf].binary) then
		text = text .. nl
	end
	return text
end

--- Toggles a buffer between bytes and an xxd dump; editing the dump edits the bytes.
---
--- Both directions go through xxd on stdin, never through the buffer's own text
--- conversions: `:%!xxd` round-tripped an ELF with a changed byte and a CRLF file
--- without its `\r`s.
---@param buf integer
function M.hex(buf)
	if vim.b[buf].sys_hex then
		local dump = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
		local res = vim.system({ "xxd", "-r" }, { stdin = dump }):wait()
		if res.code ~= 0 then
			Snacks.notify.error("xxd -r failed:\n" .. (res.stderr or ""), { title = "Hex" })
			return
		end
		local bytes = res.stdout or ""
		local lines = vim.split(bytes, "\n", { plain = true })
		local eol = lines[#lines] == ""
		if eol then
			table.remove(lines)
		end
		-- Exactly these bytes on write: no line-ending translation, no added newline.
		vim.bo[buf].binary = true
		vim.bo[buf].fileformat = "unix"
		vim.bo[buf].fixeol = false
		vim.bo[buf].eol = eol
		-- A binary was read as latin1; writing would convert these raw bytes again.
		vim.bo[buf].fileencoding = ""
		vim.bo[buf].bomb = false
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].filetype = vim.b[buf].sys_hex_ft or ""
		vim.b[buf].sys_hex = nil
		local name = vim.api.nvim_buf_get_name(buf)
		if name ~= "" and vim.uv.fs_stat(name) and vim.fn.readblob(name) == bytes then
			vim.bo[buf].modified = false
		end
	else
		local res = vim.system({ "xxd", "-g1" }, { stdin = buffer_bytes(buf) }):wait()
		if res.code ~= 0 then
			Snacks.notify.error("xxd failed:\n" .. (res.stderr or ""), { title = "Hex" })
			return
		end
		vim.b[buf].sys_hex_ft = vim.bo[buf].filetype
		local was_modified = vim.bo[buf].modified
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(vim.trim(res.stdout or ""), "\n", { plain = true }))
		vim.bo[buf].filetype = "xxd"
		vim.bo[buf].modified = was_modified
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

	vim.api.nvim_create_user_command("SysFlame", function()
		require("features.sys.profile").flame(vim.api.nvim_get_current_buf())
	end, { desc = "Folded perf stacks of the binary, rendered to SVG when a renderer exists" })

	vim.api.nvim_create_user_command("SysStrace", function(args)
		local trace = require("features.sys.trace")
		local buf = vim.api.nvim_get_current_buf()
		local what = args.fargs[1]
		if what == "summary" then
			trace.summary(buf, { class = args.fargs[2] })
		else
			trace.run(buf, { class = what })
		end
	end, {
		nargs = "*",
		complete = function()
			return vim.list_extend({ "summary" }, vim.deepcopy(require("features.sys.trace").classes))
		end,
		desc = "strace the binary: :SysStrace [class] or :SysStrace summary [class]",
	})

	vim.api.nvim_create_user_command("Qemu", function(args)
		require("features.sys.kernel").qemu(vim.api.nvim_get_current_buf(), args.fargs[1])
	end, { nargs = "?", complete = "file", desc = "Boot the tree's kernel under QEMU: :Qemu [initrd]" })

	vim.api.nvim_create_user_command("Sparse", function()
		require("features.sys.semantic").sparse(vim.api.nvim_get_current_buf())
	end, { desc = "sparse on this file, findings to quickfix" })

	vim.api.nvim_create_user_command("Coccicheck", function(args)
		local semantic = require("features.sys.semantic")
		local buf = vim.api.nvim_get_current_buf()
		if args.fargs[1] then
			semantic.run_script(buf, vim.fn.fnamemodify(args.fargs[1], ":p"))
		else
			semantic.cocci(buf)
		end
	end, { nargs = "?", complete = "file", desc = "coccinelle report mode: :Coccicheck [script.cocci]" })

	vim.api.nvim_create_user_command("SysPatch", function(args)
		local patch = require("features.sys.patch")
		local buf = vim.api.nvim_get_current_buf()
		local action = args.fargs[1]
		if action == "prep" then
			patch.prep(buf, args.fargs[2])
		elseif action == "cover" then
			patch.cover(buf)
		elseif action == "check" then
			patch.check(buf)
		elseif action == "trailers" then
			patch.trailers(buf)
		elseif action == "dry-run" or action == "send" then
			patch.send_dry_run(buf)
		elseif action == "info" then
			local cwd = vim.uv.cwd() or "."
			local dir = patch.git_root(buf) or cwd
			local info, err = patch.info(dir)
			if info then
				print(vim.inspect(info))
			else
				Snacks.notify.warn(err or "no b4 info", { title = "b4 patch" })
			end
		else
			patch.pick(buf)
		end
	end, {
		nargs = "*",
		complete = function()
			return { "prep", "cover", "check", "trailers", "dry-run", "info" }
		end,
		desc = "b4 patch series workflow: :SysPatch [prep|cover|check|trailers|dry-run|info]",
	})

	vim.api.nvim_create_user_command("SysPatchJson", function(args)
		local patch = require("features.sys.patch")
		local cwd = vim.uv.cwd() or "."
		local dir = (args.fargs and args.fargs[1] and args.fargs[1] ~= "") and args.fargs[1] or cwd
		io.stdout:write(patch.json(dir) .. "\n")
		io.stdout:flush()
		vim.cmd("qa!")
	end, { nargs = "?", complete = "dir", desc = "b4 series info as JSON: :SysPatchJson [dir]" })

	vim.api.nvim_create_user_command("SysRr", function(args)
		local run = require("features.sys.run")
		local buf = vim.api.nvim_get_current_buf()
		local action = args.fargs[1]
		if action == "replay" then
			run.rr_replay(buf)
		else
			local extra_args = #args.fargs > 1 and vim.list_slice(args.fargs, 2) or nil
			run.rr_record(buf, extra_args)
		end
	end, {
		nargs = "*",
		complete = function()
			return { "record", "replay" }
		end,
		desc = "Record binary execution with rr: :SysRr [record|replay] [args...]",
	})

	vim.api.nvim_create_user_command("SysInfo", function()
		local lines = {}
		for _, spec in ipairs(M.keys) do
			local missing = vim.tbl_filter(function(exe)
				return vim.fn.executable(exe) == 0
			end, spec.needs)
			table.insert(
				lines,
				("<leader>x%s  %-40s %s"):format(
					spec.key,
					spec.desc,
					#missing == 0 and "ok" or ("missing: " .. table.concat(missing, ", "))
				)
			)
		end
		Snacks.notify.info(table.concat(lines, "\n"), { title = "Systems tools" })
	end, { desc = "Systems tools and what they need" })
end

return M
