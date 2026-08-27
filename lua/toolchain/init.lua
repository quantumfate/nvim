--- External toolchain: the data model for every LSP server, formatter, linter and
--- debug adapter this config drives. Tools are installed by the ansible role from
--- system packages — nothing here installs anything. What this owns is the store at
--- `$XDG_STATE_HOME/nvim/tools.json`, which other programs (status bars, dashboards)
--- read to see what is present, which version, and what is missing.
---
---   :ToolchainStatus   report the current state
---   :ToolchainRefresh  re-probe PATH and rewrite the store
---   :ToolchainExport   regenerate the ansible role's package vars
---@class toolchain
local M = {}

M.registry = require("toolchain.registry")
M.store = require("toolchain.store")

--- Refreshes the store, quietly, once the session has settled. Startup stays clean:
--- the probes are async and nothing blocks on them.
local function refresh_on_idle()
	vim.api.nvim_create_autocmd("User", {
		pattern = "VeryLazy",
		once = true,
		callback = function()
			vim.defer_fn(function()
				M.store.refresh({})
			end, 2000)
		end,
	})
end

--- Human-readable summary of the store. Snacks is a global from snacks.nvim.
---@param doc table
local function report(doc)
	local lines = { ("%d/%d tools present"):format(doc.summary.present, doc.summary.total) }
	if #doc.summary.missing_tools > 0 then
		table.insert(lines, "missing: " .. table.concat(doc.summary.missing_tools, ", "))
		table.insert(lines, "install them with: cd ansible && ansible-playbook playbook.yml")
	end
	table.insert(lines, "store: " .. doc.store)
	local text = table.concat(lines, "\n")
	if #doc.summary.missing_tools > 0 then
		Snacks.notify.warn(text, { title = "Toolchain" })
	else
		Snacks.notify.info(text, { title = "Toolchain" })
	end
end

function M.setup()
	refresh_on_idle()

	vim.api.nvim_create_user_command("ToolchainStatus", function()
		local doc = M.store.read()
		if doc then
			report(doc)
		else
			M.store.refresh({}, report)
		end
	end, { desc = "Report external toolchain state" })

	vim.api.nvim_create_user_command("ToolchainRefresh", function()
		M.store.refresh({}, report)
	end, { desc = "Re-probe the toolchain and rewrite the store" })

	vim.api.nvim_create_user_command("ToolchainExport", function()
		local path = require("toolchain.export").ansible()
		Snacks.notify.info("Wrote " .. path, { title = "Toolchain" })
	end, { desc = "Regenerate the ansible role's package variables" })
end

return M
