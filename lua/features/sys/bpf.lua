--- bpftrace probes for questions perf and strace answer badly: how long syscalls
--- block, how long threads sit off-CPU, where page faults come from, what sizes get
--- malloc'd.
---
--- Each template is scoped to one process — the binary run under `-c`, or a running
--- instance by pid — so the answer is about your program and not the whole machine.
--- bpftrace needs root: passwordless sudo runs it in the background, anything else
--- opens a terminal with the exact `sudo` command so the password prompt is yours.
---@class sys.bpf
local M = {}

M.title = "bpftrace"

--- How long an attach to a running pid lasts; `-c` runs end with the program.
M.attach_seconds = 10

---@class sys.BpfTemplate
---@field name string
---@field desc string
---@field program fun(filter: string, ctx: { libc?: string }): string?

--- Probe programs. `filter` is a predicate body selecting the target's threads.
---@type sys.BpfTemplate[]
M.templates = {
	{
		name = "syscall latency",
		desc = "histogram of time spent in each syscall (µs)",
		program = function(filter)
			return table.concat({
				("tracepoint:raw_syscalls:sys_enter /%s/ { @start[tid] = nsecs; }"):format(filter),
				("tracepoint:raw_syscalls:sys_exit /%s && @start[tid]/ {"):format(filter),
				"  @usecs = hist((nsecs - @start[tid]) / 1000);",
				"  @slowest_usecs_by_syscall_id[args.id] = max((nsecs - @start[tid]) / 1000);",
				"  delete(@start[tid]);",
				"}",
				"END { clear(@start); }",
			}, "\n")
		end,
	},
	{
		name = "off-CPU time",
		desc = "how long threads were switched out, per thread",
		program = function(filter)
			-- At sched_switch the current task is the one leaving, so `pid` is the
			-- target's only on the way out; the way back in is matched by tid.
			return table.concat({
				("tracepoint:sched:sched_switch /%s/ { @start[args.prev_pid] = nsecs; }"):format(filter),
				"tracepoint:sched:sched_switch /@start[args.next_pid]/ {",
				"  $us = (nsecs - @start[args.next_pid]) / 1000;",
				"  @offcpu_usecs = hist($us);",
				"  @offcpu_usecs_by_tid[args.next_pid] = sum($us);",
				"  delete(@start[args.next_pid]);",
				"}",
				"END { clear(@start); }",
			}, "\n")
		end,
	},
	{
		name = "page faults",
		desc = "page faults by user stack",
		program = function(filter)
			return ("software:page-faults:1 /%s/ { @faults_by_stack[ustack] = count(); @total = count(); }"):format(
				filter
			)
		end,
	},
	{
		name = "malloc sizes",
		desc = "histogram of malloc request sizes (uprobe on libc)",
		program = function(filter, ctx)
			if not ctx.libc then
				return nil
			end
			return ("uprobe:%s:malloc /%s/ { @bytes = hist(arg0); @calls = count(); }"):format(ctx.libc, filter)
		end,
	},
}

--- The libc a binary loads, from `ldd` output. Statically linked binaries have none.
---@param lines string[]
---@return string?
function M.libc_from_ldd(lines)
	for _, line in ipairs(lines) do
		local path = line:match("^%s*libc%.so%.%d+ => (%S+)")
		if path then
			return path
		end
	end
	return nil
end

---@alias sys.BpfTarget { cmd: string }|{ pid: integer }

--- The bpftrace argv for a template against a target, without any privilege prefix.
---
--- `-c` makes `cpid` the child, and `pid` is the thread group, so one predicate
--- covers every thread. A pid attach gets an interval probe that exits, since
--- nothing else would end it.
---@param template sys.BpfTemplate
---@param target sys.BpfTarget
---@param ctx? { libc?: string, seconds?: integer }
---@return string[]? argv, string? err
function M.command(template, target, ctx)
	ctx = ctx or {}
	local filter = target.cmd and "pid == cpid" or ("pid == %d"):format(target.pid)
	local program = template.program(filter, ctx)
	if not program then
		return nil, template.name .. " needs a dynamically linked libc"
	end
	if target.pid then
		program = program .. ("\ninterval:s:%d { exit(); }"):format(ctx.seconds or M.attach_seconds)
	end
	local argv = { "bpftrace", "-B", "line" }
	if target.cmd then
		vim.list_extend(argv, { "-c", target.cmd })
	else
		vim.list_extend(argv, { "-p", tostring(target.pid) })
	end
	vim.list_extend(argv, { "-e", program })
	return argv
end

--- How to get root: nothing when already root, `sudo -n` when it needs no password,
--- nil when a password is required.
---@return string[]?
function M.privilege()
	if vim.uv.getuid() == 0 then
		return {}
	end
	local ok, res = pcall(function()
		return vim.system({ "sudo", "-n", "true" }, { text = true }):wait(3000)
	end)
	if ok and res.code == 0 then
		return { "sudo", "-n" }
	end
	return nil
end

--- Runs `argv` and shows what bpftrace printed; the maps are dumped at exit.
---@param buf integer
---@param argv string[]
---@param root string
---@param heading string
local function run_background(buf, argv, root, heading)
	require("features.sys.util").chain(M.title, { { cmd = argv, cwd = root } }, function(results)
		local res = results[#results]
		local lines = { heading, "" }
		vim.list_extend(
			lines,
			vim.split(vim.trim((res.stdout or "") .. "\n" .. (res.stderr or "")), "\n", { plain = true })
		)
		require("features.lang.output").show({ title = M.title, lines = lines, source = buf, link = false })
	end)
end

--- Picks a template and a target, then runs it with whatever root access exists.
---@param buf integer
function M.pick(buf)
	local output = require("features.lang.output")
	if not output.require_exe("bpftrace") then
		return
	end
	local root = require("lib.root").get({ buf = buf })
	vim.ui.select(M.templates, {
		prompt = "bpftrace probe",
		format_item = function(tpl)
			return ("%-16s %s"):format(tpl.name, tpl.desc)
		end,
	}, function(template)
		if not template then
			return
		end
		require("features.sys.util").binary(buf, function(bin)
			local name = vim.fs.basename(bin)
			-- pgrep matches the 15-byte comm, which truncates longer names.
			local pids = vim.split(
				vim.trim(vim.system({ "pgrep", "-x", name:sub(1, 15) }, { text = true }):wait().stdout or ""),
				"\n",
				{ trimempty = true }
			)
			local targets = { { label = "run " .. name, target = { cmd = bin } } }
			for _, pid in ipairs(pids) do
				table.insert(targets, {
					label = ("attach to %s (pid %s, %ds)"):format(name, pid, M.attach_seconds),
					target = { pid = tonumber(pid) },
				})
			end
			vim.ui.select(targets, {
				prompt = "Target",
				format_item = function(item)
					return item.label
				end,
			}, function(choice)
				if not choice then
					return
				end
				local ldd = vim.system({ "ldd", bin }, { text = true }):wait()
				local argv, err =
					M.command(template, choice.target, { libc = M.libc_from_ldd(vim.split(ldd.stdout or "", "\n")) })
				if not argv then
					Snacks.notify.warn(err or "no bpftrace command for this target", { title = M.title })
					return
				end
				local prefix = M.privilege()
				if prefix then
					run_background(
						buf,
						vim.list_extend(prefix, argv),
						root,
						("%s · %s"):format(template.name, choice.label)
					)
				else
					output.terminal(
						vim.list_extend({ "sudo" }, argv),
						root,
						{ title = "sudo bpftrace · " .. template.name }
					)
				end
			end)
		end)
	end)
end

return M
