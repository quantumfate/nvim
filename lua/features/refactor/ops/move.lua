--- Move a declaration into another file.
---
--- The edits are the easy half: cut here, paste there. What makes it a refactoring
--- rather than a yank is that the preview shows both files and the usages that will
--- need an import, which no amount of treesitter can write for you across languages.
---@class refactor.ops.move
local M = {}

local syntax = require("features.refactor.syntax")
local usages = require("features.refactor.usages")
local imports = require("features.refactor.imports")
local visibility = require("features.refactor.visibility")
local Plan = require("features.refactor.plan")

--- Moves the enclosing function to `path`, creating it when absent.
---@param opts? { path?: string, preview?: boolean }
function M.run(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_get_current_buf()

	local range = require("features.ts_scope").enclosing("function.outer")
	if not range then
		Snacks.notify.warn("Cursor is not inside a function", { title = "Refactor" })
		return
	end
	local srow, scol, erow, ecol = range[1], range[2], range[3], range[4]

	-- The doc comment travels with the declaration; leaving it behind would strand it
	-- on whatever follows, and the moved function would arrive undocumented.
	local from = syntax.doc_start(bufnr, srow)
	local body = table.concat(vim.api.nvim_buf_get_text(bufnr, from, 0, erow, ecol, {}), "\n")

	local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { srow, scol } })
	local name_node = node and node:field("name")[1]
	local name = name_node and syntax.text(name_node, bufnr) or "declaration"
	if not node then
		Snacks.notify.warn("Cannot identify the declaration to move", { title = "Refactor" })
		return
	end

	local proceed = function(path)
		if not path or vim.trim(path) == "" then
			return
		end
		path = vim.fn.fnamemodify(vim.trim(path), ":p")

		local plan = Plan.new(("Move %s → %s"):format(name, vim.fn.fnamemodify(path, ":~:.")))

		-- Cut from here.
		plan:edit(bufnr, {
			range = { start = { line = from, character = 0 }, ["end"] = { line = erow + 1, character = 0 } },
			newText = "",
		})

		-- Paste at the end of the destination, creating the buffer if the file is new.
		local target = plan:bufnr(vim.uri_from_fname(path))
		local last = vim.api.nvim_buf_line_count(target)
		plan:edit(target, syntax.insert(last, 0, "\n" .. body .. "\n"))

		-- A file-private symbol cannot be reached from its new home. Nothing about the
		-- move says so, and the callers left behind only fail at run time.
		local vis = visibility.of(node, bufnr)
		if vis == "unknown" then
			plan:skipped_check("visibility", vim.bo[bufnr].filetype .. " does not mark visibility syntactically")
		end
		if vis == "private" then
			plan:note(
				"conflict",
				bufnr,
				srow,
				scol,
				("`%s` is private to this file; moving it puts it out of reach of its callers"):format(name)
			)
		end

		-- What the moved code uses but does not define has to come with it.
		local free = imports.free_names(bufnr, from, erow)
		if #free > 0 and imports.supported(bufnr) then
			plan:note(
				"skip",
				bufnr,
				srow,
				scol,
				("uses %d name(s) from this file: %s"):format(#free, table.concat(free, ", "))
			)
		end

		if not imports.supported(bufnr) then
			plan:skipped_check("imports", "not written automatically for " .. vim.bo[bufnr].filetype)
		end

		usages.lsp(bufnr, { include_declaration = false }, function(found, _, reason)
			if not found then
				plan:skipped_check("call sites", reason or "usages unavailable")
			end
			-- Every file that referenced the symbol now needs to import it from its new
			-- home. For languages whose import form is a rule, write it; for the rest,
			-- say so rather than guess.
			local importing = {}
			for _, usage in ipairs(found or {}) do
				if usage.bufnr ~= bufnr and not importing[usage.bufnr] then
					importing[usage.bufnr] = true
					local statement = imports.needed(usage.bufnr, path, name)
					if statement then
						local row = imports.insert_row(usage.bufnr)
						plan:edit(usage.bufnr, syntax.insert(row, 0, statement .. "\n"))
						if Plan.owns(usage.bufnr) or usage.opened then
							plan:adopt(usage.bufnr)
						end
					elseif not imports.supported(usage.bufnr) then
						plan:note(
							"skip",
							usage.bufnr,
							usage.range.start.line,
							usage.range.start.character,
							"this language's imports are not written automatically"
						)
					end
				end
			end

			-- And the file it left, if it still uses the symbol itself.
			local statement = imports.needed(bufnr, path, name)
			if statement and #imports.free_names(bufnr, 0, vim.api.nvim_buf_line_count(bufnr)) > 0 then
				plan:edit(bufnr, syntax.insert(imports.insert_row(bufnr), 0, statement .. "\n"))
			end

			Plan.finish(plan, opts)
		end)
	end

	if opts.path then
		proceed(opts.path)
	else
		vim.ui.input(
			{ prompt = "Move to file: ", default = vim.fn.expand("%:p:h") .. "/", completion = "file" },
			proceed
		)
	end
end

return M
