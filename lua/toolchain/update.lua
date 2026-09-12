--- `:ToolchainUpdate`: the layer pacman does not own — rustup, cargo, luarocks, the
--- unpackaged debug adapter, plugins. Manual by design.
---@class toolchain.update
local M = {}

local registry = require("toolchain.registry")
local notify = require("toolchain.notify")
local store = require("toolchain.store")

---@param cmd string
---@return string
local function expand(cmd)
	-- stdpath("data") already ends in /nvim; the registry's paths add it themselves.
	local home = vim.uv.os_homedir() or ""
	local data_home = vim.env.XDG_DATA_HOME or (home .. "/.local/share")
	return (cmd:gsub("%$XDG_DATA_HOME", data_home):gsub("%$HOME", home))
end

---@param entry { eco: string, step: toolchain.Step }
---@param on_done fun(ok: boolean, detail: string)
local function run_step(entry, on_done)
	local started = vim.uv.now()
	vim.system({ "sh", "-c", expand(entry.step.cmd) }, { text = true }, function(res)
		local ok = res.code == 0
		local output = vim.trim((res.stderr or "") ~= "" and res.stderr or (res.stdout or ""))
		local detail = vim.split(output, "\n", { plain = true })
		-- The last lines are where a build says what went wrong.
		local tail = table.concat(vim.list_slice(detail, math.max(#detail - 2, 1)), " | ")

		notify.event({
			status = ok and "ok" or "failed",
			phase = "update",
			ecosystem = entry.eco,
			tool = entry.step.name,
			exit = res.code,
			detail = ok and ("%dms"):format(vim.uv.now() - started) or tail,
		})
		on_done(ok, tail)
	end)
end

---@param on_done fun(ok: boolean, detail: string)
local function update_plugins(on_done)
	local ok, lazy = pcall(require, "lazy")
	if not ok then
		on_done(true, "lazy.nvim not loaded")
		return
	end
	lazy.update({ show = false, wait = false })
	-- lazy reports through its own UI; dispatch is all we can report on.
	notify.event({ status = "ok", phase = "update", tool = "plugins", detail = "lazy.nvim update started" })
	on_done(true, "started")
end

---@class toolchain.UpdateOpts
---@field ecosystems? string[] Restrict to these; defaults to every updatable ecosystem
---@field plugins? boolean Also update plugins; defaults to true
---@field dry_run? boolean Print what would run, change nothing
---@field on_finish? fun() Called after the store has been refreshed

---@param opts? toolchain.UpdateOpts
function M.run(opts)
	opts = opts or {}
	local steps = registry.update_steps(opts.ecosystems)

	if opts.dry_run then
		local lines = vim.tbl_map(function(entry)
			return ("%s/%s: %s"):format(entry.eco, entry.step.name, expand(entry.step.cmd))
		end, steps)
		Snacks.notify.info(table.concat(lines, "\n"), { title = "Toolchain update (dry run)" })
		return
	end

	if #steps == 0 then
		Snacks.notify.warn("nothing to update", { title = "Toolchain update" })
		return
	end

	local failed = {}
	local index = 0

	local function step_done()
		index = index + 1
		if index > #steps then
			-- Versions changed underneath us; the store has to be re-read, not trusted.
			store.refresh({}, function(doc)
				local status = #failed == 0 and "ok" or "failed"
				notify.event({
					status = status,
					phase = "update",
					tool = "toolchain",
					exit = #failed,
					detail = #failed == 0 and ("%d steps ok, %d tools present"):format(#steps, doc.summary.present)
						or ("failed: " .. table.concat(failed, ", ")),
				})
				if opts.on_finish then
					opts.on_finish()
				end
				local text = ("%d/%d steps ok"):format(#steps - #failed, #steps)
				if #failed == 0 then
					Snacks.notify.info(text, { title = "Toolchain update" })
				else
					Snacks.notify.error(
						text .. "\nfailed: " .. table.concat(failed, ", "),
						{ title = "Toolchain update" }
					)
				end
			end)
			return
		end

		local entry = steps[index]
		Snacks.notify.info(
			("[%d/%d] %s/%s"):format(index, #steps, entry.eco, entry.step.name),
			{ title = "Toolchain update", id = "toolchain_update" }
		)
		run_step(entry, function(ok)
			if not ok then
				table.insert(failed, entry.eco .. "/" .. entry.step.name)
			end
			vim.schedule(step_done)
		end)
	end

	if opts.plugins ~= false then
		update_plugins(function() end)
	end
	step_done()
end

---@param fargs string[]
---@return toolchain.UpdateOpts
function M.parse(fargs)
	local opts = { ecosystems = {} }
	for _, arg in ipairs(fargs) do
		if arg == "--dry-run" then
			opts.dry_run = true
		elseif arg == "--no-plugins" then
			opts.plugins = false
		else
			table.insert(opts.ecosystems, arg)
		end
	end
	if #opts.ecosystems == 0 then
		opts.ecosystems = nil
	end
	return opts
end

return M
