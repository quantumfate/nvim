--- Guards against the mistake this config kept making: a buffer-local mapping quietly
--- shadowing a global one.
---
--- Three shipped. `<leader>rn` hid the prose-aware rename behind inc-rename, `<leader>id`
--- hid the database picker behind a diagnostics preset, and `<leader>ie` hid "equalize
--- windows". None of them error — the key simply does something else, in some buffers,
--- and you find out weeks later.
local t = require("tests.harness")

--- Leader keys that are *meant* to be overridden per buffer, with the reason.
---@type table<string, string>
local INTENTIONAL = {}

--- Buffer-local mappings that shadow a global one with a different meaning.
---@return string[]
local function collisions()
	local global = {}
	for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
		global[map.lhs] = map.desc
	end

	local found = {}
	for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
		local shadowed = global[map.lhs]
		-- Leader keys only: `gr*`, `]d` and friends are nvim defaults this config
		-- overrides on purpose, and every LSP buffer would report them.
		if map.lhs:match("^ ") and shadowed and shadowed ~= map.desc and not INTENTIONAL[map.lhs] then
			table.insert(found, ("%s  buffer:%q shadows global:%q"):format(map.lhs, map.desc or "", shadowed))
		end
	end
	table.sort(found)
	return found
end

--- Every `<leader>…` this config binds, from the source, as key -> where it was found.
---
--- Runtime cannot answer this: two `vim.keymap.set` calls on the same key leave one
--- mapping, so the loser is invisible. `<leader>ie` was bound twice for a while and the
--- only symptom was that "equalize windows" had quietly become a diagnostics preset.
---@return table<string, string[]>
local function declared_leader_keys()
	local found = {}
	for _, path in ipairs(vim.fn.glob("lua/**/*.lua", false, true)) do
		local source = table.concat(vim.fn.readfile(path), "\n")
		for line in source:gmatch("[^\n]+") do
			-- Definitions only. Not prose, and not which-key `group =` labels, which
			-- name a prefix rather than binding it — `<leader>w` is a group *and* the
			-- prefix of a dozen real bindings.
			local is_definition = line:match("keymap%.set")
				or line:match("^%s*map%(")
				or line:match('^%s*{%s*"<leader>')
			if is_definition and not line:match("group%s*=") then
				for key in line:gmatch('"(<leader>%w[%w]?)"') do
					found[key] = found[key] or {}
					if not vim.tbl_contains(found[key], path) then
						table.insert(found[key], path)
					end
				end
			end
		end
	end
	return found
end

t.describe("keymaps", function()
	t.it("no leader key is shadowed by a buffer-local mapping", function()
		t.reset()
		-- A plain buffer carries whatever global mappings exist; the per-filetype ones
		-- are added by LspAttach and FileType, which a headless spec cannot rely on. So
		-- this catches the global-vs-global-plus-plugin case, which is where all three
		-- real collisions came from.
		local found = collisions()
		t.eq({}, found, "a leader key is shadowed:\n  " .. table.concat(found, "\n  "))
	end)

	t.it("no leader key is bound in two places", function()
		local duplicates = {}
		for key, paths in pairs(declared_leader_keys()) do
			if #paths > 1 then
				table.insert(duplicates, ("%s in %s"):format(key, table.concat(paths, " and ")))
			end
		end
		table.sort(duplicates)
		t.eq({}, duplicates, "a leader key is bound twice:\n  " .. table.concat(duplicates, "\n  "))
	end)

	t.it("every language capability key is unique within its group", function()
		local lang = require("features.lang")
		local seen = {}
		for name, cap in pairs(lang.capabilities) do
			local key = cap.group .. cap.key
			t.ok(not seen[key], ("%s and %s share %s%s"):format(name, seen[key] or "?", cap.group, cap.key))
			seen[key] = name
		end
		-- The server-provided ones share the `view` prefix, so they must not collide
		-- with a capability key either.
		for name, cap in pairs(lang.lsp_capabilities) do
			local key = "view" .. cap.key
			t.ok(not seen[key], ("%s and %s share view%s"):format(name, seen[key] or "?", cap.key))
			seen[key] = name
		end
	end)

	t.it("rendered views name their title through the declaration", function()
		-- A view whose title is a literal can drift from `M.titles`, and then its key
		-- never reports the view as showing — it opens a second copy instead of closing
		-- the first. Referencing `M.titles.<cap>` makes that impossible, so the test is
		-- that no `output.run` call spells its title out.
		for _, ft in ipairs({ "c", "zig", "rust", "lua" }) do
			local source = table.concat(vim.fn.readfile("lua/features/lang/" .. ft .. ".lua"), "\n")
			for call in source:gmatch("output%.run%b()") do
				local literal = call:match('title%s*=%s*"([^"]+)"')
				t.ok(
					not literal,
					("%s passes a literal title %q to output.run; use M.titles.<capability>"):format(ft, literal or "")
				)
			end
		end
	end)

	t.it("every declared title is one a capability actually renders", function()
		-- The other direction: a title left in the table after its capability was
		-- removed is a key that toggles something which no longer exists.
		local lang = require("features.lang")
		for _, ft in ipairs({ "c", "zig", "rust", "lua" }) do
			local adapter = lang.adapter(ft)
			assert(adapter)
			for capability in pairs(adapter.titles or {}) do
				t.ok(
					adapter[capability],
					("%s declares a title for %s, which it does not implement"):format(ft, capability)
				)
			end
		end
	end)
end)
