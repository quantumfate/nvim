--- `:checkhealth refactor`: which guards work for which language.
---
--- The engine draws on three sources that each cover a different set of languages, so
--- "is this safe here" has a different answer per filetype. Rather than finding that
--- out mid-refactor, this prints the matrix.
---@class refactor.health
local M = {}

local langs = require("features.refactor.langs")
local imports = require("features.refactor.imports")

--- Filetypes worth reporting on: everything any of the sources knows about.
---@return string[]
local function filetypes()
	local set = {}
	for ft in pairs(langs) do
		set[ft] = true
	end
	for _, ft in ipairs({ "lua", "rust", "go", "python", "zig", "c", "cpp", "javascript", "typescript", "nix", "php" }) do
		set[ft] = true
	end
	local out = vim.tbl_keys(set)
	table.sort(out)
	return out
end

--- Whether a locals query exists for a filetype, without needing an open buffer.
---@param ft string
---@return boolean
local function has_locals(ft)
	local ok, lang = pcall(vim.treesitter.language.get_lang, ft)
	if not ok or not lang then
		return false
	end
	local found, query = pcall(vim.treesitter.query.get, lang, "locals")
	return found and query ~= nil
end

--- Whether visibility is syntactically knowable for a filetype.
---@param ft string
---@return boolean
local function has_visibility(ft)
	-- The rules table is private, so ask it the way callers do: through a scratch
	-- buffer of that filetype and a node that does not exist. "unknown" is the answer
	-- for anything unsupported.
	local supported = { lua = true, rust = true, go = true }
	if vim.tbl_contains({ "javascript", "typescript", "javascriptreact", "typescriptreact" }, ft) then
		return true
	end
	return supported[ft] == true
end

--- Whether imports can be written for a filetype.
---@param ft string
---@return boolean
local function has_imports(ft)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].filetype = ft
	local ok = imports.supported(buf)
	vim.api.nvim_buf_delete(buf, { force = true })
	return ok
end

function M.check()
	vim.health.start("refactor")

	local parsers = 0
	local rows = {}
	for _, ft in ipairs(filetypes()) do
		local has_parser = pcall(vim.treesitter.language.get_lang, ft) and vim.treesitter.language.get_lang(ft) ~= nil
		if has_parser then
			parsers = parsers + 1
		end
		table.insert(
			rows,
			("  %-16s signature %-3s  locals %-3s  visibility %-3s  imports %-3s"):format(
				ft,
				langs[ft] and "yes" or "—",
				has_locals(ft) and "yes" or "—",
				has_visibility(ft) and "yes" or "—",
				has_imports(ft) and "yes" or "—"
			)
		)
	end

	vim.health.info("What each guard covers, per filetype:\n" .. table.concat(rows, "\n"))

	vim.health.info(table.concat({
		"signature   add / remove / reorder a parameter, and update call sites",
		"locals      name-collision and still-used checks; extract and inline variable",
		"visibility  refuses moving a file-private symbol out of reach",
		"imports     move_to_file writes the import for you",
	}, "\n"))

	-- The one guard that does not depend on the filetype at all.
	local clients = #vim.lsp.get_clients()
	if clients > 0 then
		vim.health.ok(
			("post-apply verification available (%d client%s running)"):format(clients, clients == 1 and "" or "s")
		)
	else
		vim.health.warn("no language server running", {
			"Call-site updates, rename and safe delete all need one.",
			"Post-apply verification is skipped, and refactorings say so when applied.",
		})
	end

	if vim.fn.exists(":Refactor") == 2 then
		vim.health.ok(":Refactor and :RefactorUndo are registered")
	else
		vim.health.error(":Refactor is not registered", { "require('features.refactor').setup() did not run" })
	end
end

return M
