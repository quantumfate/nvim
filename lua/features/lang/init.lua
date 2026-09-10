--- One keymap set for every language.
---
--- Each ecosystem exposes its power through a different door: rustaceanvim has
--- `:RustLsp` subcommands, clangd has LSP extensions, zig has a CLI, lua_ls has almost
--- nothing. Left alone that means four sets of muscle memory for the same handful of
--- questions — what does this expand to, what assembly does it become, who calls this,
--- build it, test it.
---
--- So the questions get the keys, and each language answers the ones it can. An
--- adapter that cannot answer one does not bind it, which is why which-key only ever
--- shows what actually works in the buffer you are in.
---@class lang
local M = {}

--- The vocabulary. Adding a capability here and implementing it in an adapter is the
--- whole extension path; the keys never move.
---@class lang.Capability
---@field key string After the group prefix
---@field desc string
---@field group "build"|"view"

---@type table<string, lang.Capability>
M.capabilities = {
	-- Build loop: `<leader>b`.
	build = { key = "b", desc = "Build", group = "build" },
	run = { key = "r", desc = "Run", group = "build" },
	run_other = { key = "R", desc = "Run (choose target)", group = "build" },
	test = { key = "t", desc = "Test", group = "build" },
	check = { key = "c", desc = "Check (fast, no codegen)", group = "build" },
	build_file = { key = "o", desc = "Open build file", group = "build" },
	reload = { key = "i", desc = "Reload project index", group = "build" },

	-- Inspection: `<leader>v`. What the compiler actually sees and emits.
	expand = { key = "e", desc = "Expand macros / preprocess", group = "view" },
	assembly = { key = "a", desc = "Assembly", group = "view" },
	ir = { key = "i", desc = "Intermediate representation", group = "view" },
	tree = { key = "t", desc = "Syntax tree", group = "view" },
	related = { key = "h", desc = "Switch to related file", group = "view" },
	symbol = { key = "s", desc = "Symbol details", group = "view" },
}

--- Capabilities every language gets from the language server, so no adapter has to
--- reimplement them. Bound only when the attached server advertises the method.
---@type table<string, { key: string, desc: string, method: string, run: fun() }>
M.lsp_capabilities = {
	incoming = {
		key = "c",
		desc = "Incoming calls (who calls this)",
		method = "callHierarchy/incomingCalls",
		run = function()
			vim.lsp.buf.incoming_calls()
		end,
	},
	outgoing = {
		key = "C",
		desc = "Outgoing calls (what this calls)",
		method = "callHierarchy/outgoingCalls",
		run = function()
			-- Outgoing calls are a property of a *definition*: "what does this function
			-- call". Asked at a call site the server answers about the caller, which is
			-- usually the enclosing function and often nothing at all — an empty
			-- quickfix with no explanation.
			local before = #vim.fn.getqflist()
			vim.lsp.buf.outgoing_calls()
			vim.defer_fn(function()
				if #vim.fn.getqflist() == before then
					Snacks.notify.info(
						"No outgoing calls here.\nPut the cursor on a function's name — outgoing calls answer"
							.. " 'what does this call', so a call site has nothing to report.",
						{ title = "Call hierarchy" }
					)
				end
			end, 700)
		end,
	},
	supertypes = {
		key = "y",
		desc = "Supertypes",
		method = "typeHierarchy/supertypes",
		run = function()
			vim.lsp.buf.typehierarchy("supertypes")
		end,
	},
	subtypes = {
		key = "Y",
		desc = "Subtypes",
		method = "typeHierarchy/subtypes",
		run = function()
			vim.lsp.buf.typehierarchy("subtypes")
		end,
	},
}

local PREFIX = { build = "<leader>b", view = "<leader>v" }

--- The title an adapter renders a capability under, or nil when the capability opens
--- a window of its own (rustaceanvim's views, `:InspectTree`, a terminal). Those are
--- not toggled by us, because we did not open them.
---@param ft string
---@param capability string
---@return string?
function M.title(ft, capability)
	local adapter = M.adapter(ft)
	return adapter and (adapter.titles or {})[capability] or nil
end

--- The adapter for a filetype, or nil.
---@param ft string
---@return table?
function M.adapter(ft)
	local ok, adapter = pcall(require, "features.lang." .. ft)
	return ok and type(adapter) == "table" and adapter or nil
end

--- Binds every capability the adapter implements, buffer-locally.
---@param buf integer
---@param ft string
local function install(buf, ft)
	-- Output panes carry a real filetype (assembly is `asm`, preprocessed C is `c`)
	-- but no file behind them.
	if vim.b[buf].lang_output then
		return
	end

	local adapter = M.adapter(ft)
	if not adapter then
		return
	end

	for name, cap in pairs(M.capabilities) do
		local fn = adapter[name]
		if fn then
			vim.keymap.set("n", PREFIX[cap.group] .. cap.key, function()
				-- Pressing the same key again closes the view; pressing a different one
				-- replaces it. So a view is never something you have to go and find a
				-- way out of.
				local output = require("features.lang.output")
				local title = M.title(ft, name)
				if title and output.showing(title) then
					output.close(title)
					return
				end
				fn(buf)
			end, { buffer = buf, desc = cap.desc })
		end
	end
end

--- Binds the server-provided capabilities once a client that supports them attaches.
---@param buf integer
---@param client vim.lsp.Client
local function install_lsp(buf, client)
	for _, cap in pairs(M.lsp_capabilities) do
		if client:supports_method(cap.method) then
			vim.keymap.set("n", PREFIX.view .. cap.key, cap.run, { buffer = buf, desc = cap.desc })
		end
	end
end

--- What the current buffer's language can and cannot do, for `:LangInfo`.
---@return string[]
function M.report()
	local ft = vim.bo.filetype
	local adapter = M.adapter(ft)
	local lines = { ("filetype: %s"):format(ft == "" and "none" or ft) }

	if not adapter then
		table.insert(lines, "no adapter; only the shared LSP actions are bound")
	end

	local names = vim.tbl_keys(M.capabilities)
	table.sort(names)
	for _, name in ipairs(names) do
		local cap = M.capabilities[name]
		table.insert(
			lines,
			("  %s%-2s %-32s %s"):format(
				PREFIX[cap.group] == "<leader>b" and "<leader>b" or "<leader>v",
				cap.key,
				cap.desc,
				(adapter and adapter[name]) and "yes" or "—"
			)
		)
	end

	local client = vim.lsp.get_clients({ bufnr = 0 })[1]
	table.insert(lines, client and ("server: " .. client.name) or "server: none attached")
	for _, key in ipairs({ "incoming", "outgoing", "supertypes", "subtypes" }) do
		local cap = M.lsp_capabilities[key]
		local ok = client and client:supports_method(cap.method)
		table.insert(lines, ("  <leader>v%-2s %-32s %s"):format(cap.key, cap.desc, ok and "yes" or "—"))
	end

	return lines
end

--- Registers the FileType and LspAttach hooks that install the keymaps.
function M.setup()
	require("features.lang.output").setup()

	local group = vim.api.nvim_create_augroup("lang_actions", { clear = true })

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		callback = function(ev)
			install(ev.buf, vim.bo[ev.buf].filetype)
		end,
	})

	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		callback = function(ev)
			local client = vim.lsp.get_client_by_id(ev.data.client_id)
			if client then
				install_lsp(ev.buf, client)
			end
		end,
	})

	vim.api.nvim_create_user_command("LangJobs", function()
		vim.notify(
			table.concat(require("features.lang.jobs").report(), "\n"),
			vim.log.levels.INFO,
			{ title = "Background jobs" }
		)
	end, { desc = "What is compiling in the background" })

	vim.api.nvim_create_user_command("LangInfo", function()
		vim.notify(table.concat(M.report(), "\n"), vim.log.levels.INFO, { title = "Language actions" })
	end, { desc = "What the current language supports, and on which keys" })
end

return M
