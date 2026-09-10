--- Project scaffolder. Generates best-practice config for the open project, tailored
--- to its detected ecosystems. Everything derives from one wiring table
--- (scaffold.tools); pre-commit, the flake, the ansible playbook, and CI all call the
--- same `just` recipes. Non-destructive unless `--force`.
---
--- Commands:
---   :ProjectScaffold [scope...] [--force]  Generate. A scope force-includes an
---       ecosystem (rust wiring before any .rs exists) or filters to a category.
---   :ProjectDoctor    Read-only health, hygiene, and secret report.
---   :ProjectSanitize  Fix trailing whitespace, newlines, tracked junk, script perms.
---
--- Only the command registration lives here. The generator and its template set are
--- ~1600 lines that nothing needs to edit a file, so they load on first invocation.
---@class scaffold
local M = {}

--- The generator module, required on demand.
---@return scaffold.generate
local function generate()
	return require("scaffold.generate")
end

function M.setup()
	vim.api.nvim_create_user_command("ProjectScaffold", function(args)
		local gen = generate()
		local opts, unknown = gen.parse_args(args.fargs, args.bang)
		if #unknown > 0 then
			Snacks.notify.warn("Scaffold: ignoring unknown args: " .. table.concat(unknown, ", "))
		end
		gen.run(opts)
	end, {
		bang = true,
		nargs = "*",
		complete = function(arg_lead)
			return generate().complete(arg_lead)
		end,
		desc = "Generate best-practice config ([scope...] [--force])",
	})

	vim.api.nvim_create_user_command("ProjectDoctor", function()
		generate().doctor()
	end, { desc = "Report missing config, toolchain, junk, and secrets" })

	vim.api.nvim_create_user_command("ProjectSanitize", function()
		generate().sanitize()
	end, { desc = "Auto-fix whitespace, newlines, tracked junk, and script perms" })
end

return M
