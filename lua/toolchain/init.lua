--- Commands and startup wiring for the toolchain modules.
---@class toolchain
local M = {}

-- Lazy proxies: the registry is a 376-line table and the store only runs 2s after
-- VeryLazy, but setup() has to register commands during startup.
local lazy = require("lib.modules").require_on_index
M.registry = lazy("toolchain.registry")
M.store = lazy("toolchain.store")

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

	vim.api.nvim_create_user_command("ToolchainDashboard", function()
		require("toolchain.dashboard").open()
	end, { desc = "Toolchain report with update actions" })

	-- <leader>i is the "interfaces" group (see whichkey).
	vim.keymap.set("n", "<leader>it", function()
		require("toolchain.dashboard").open()
	end, { desc = "Toolchain" })

	vim.api.nvim_create_user_command("ToolchainUpdate", function(args)
		require("toolchain.update").run(require("toolchain.update").parse(args.fargs))
	end, {
		nargs = "*",
		complete = function(lead)
			local candidates = vim.list_extend(M.registry.updatable(), { "--dry-run", "--no-plugins" })
			return vim.tbl_filter(function(name)
				return name:find(lead, 1, true) == 1
			end, candidates)
		end,
		desc = "Update the tools pacman does not own ([ecosystem...] [--dry-run] [--no-plugins])",
	})

	vim.api.nvim_create_user_command("ToolchainExport", function()
		local path = require("toolchain.export").ansible()
		Snacks.notify.info("Wrote " .. path, { title = "Toolchain" })
	end, { desc = "Regenerate the ansible role's package variables" })
end

return M
