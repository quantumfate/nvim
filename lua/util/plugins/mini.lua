--- mini.nvim helpers: whole-buffer text object, smart pairs, and which-key registration.
---@class util.plugins.mini
local mini = {}

--- Whole-buffer text object; "i" trims leading/trailing blank lines, "a" spans everything.
---@param ai_type "a"|"i"
---@return table region { from, to } positions
function mini.ai_buffer(ai_type)
	local start_line, end_line = 1, vim.fn.line("$")
	if ai_type == "i" then
		-- Skip first and last blank lines for `i` textobject
		local first_nonblank, last_nonblank = vim.fn.nextnonblank(start_line), vim.fn.prevnonblank(end_line)
		-- Do nothing for buffer with all blanks
		if first_nonblank == 0 or last_nonblank == 0 then
			return { from = { line = start_line, col = 1 } }
		end
		start_line, end_line = first_nonblank, last_nonblank
	end

	local to_col = math.max(vim.fn.getline(end_line):len(), 1)
	return { from = { line = start_line, col = 1 }, to = { line = end_line, col = to_col } }
end

--- Sets up mini.pairs with a Snacks toggle and context-aware open (markdown/treesitter/unbalanced).
--- Snacks and vim.g.minipairs_disable are external globals.
---@param opts {skip_next: string, skip_ts: string[], skip_unbalanced: boolean, markdown: boolean}
function mini.pairs(opts)
	Snacks.toggle({
		name = "Mini Pairs",
		get = function()
			return not vim.g.minipairs_disable
		end,
		set = function(state)
			vim.g.minipairs_disable = not state
		end,
	}):map("<leader>tp")

	local pairs = require("mini.pairs")
	pairs.setup(opts)
	local open = pairs.open
	pairs.open = function(pair, neigh_pattern)
		if vim.fn.getcmdline() ~= "" then
			return open(pair, neigh_pattern)
		end
		local o, c = pair:sub(1, 1), pair:sub(2, 2)
		local line = vim.api.nvim_get_current_line()
		local cursor = vim.api.nvim_win_get_cursor(0)
		local next = line:sub(cursor[2] + 1, cursor[2] + 1)
		local before = line:sub(1, cursor[2])
		if opts.markdown and o == "`" and vim.bo.filetype == "markdown" and before:match("^%s*``") then
			return "`\n```" .. vim.api.nvim_replace_termcodes("<up>", true, true, true)
		end
		if opts.skip_next and next ~= "" and next:match(opts.skip_next) then
			return o
		end
		if opts.skip_ts and #opts.skip_ts > 0 then
			local ok, captures = pcall(vim.treesitter.get_captures_at_pos, 0, cursor[1] - 1, math.max(cursor[2] - 1, 0))
			for _, capture in ipairs(ok and captures or {}) do
				if vim.tbl_contains(opts.skip_ts, capture.capture) then
					return o
				end
			end
		end
		if opts.skip_unbalanced and next == c and c ~= o then
			local _, count_open = line:gsub(vim.pesc(pair:sub(1, 1)), "")
			local _, count_close = line:gsub(vim.pesc(pair:sub(2, 2)), "")
			if count_close > count_open then
				return o
			end
		end
		return open(pair, neigh_pattern)
	end
end

--- Registers which-key descriptions for every mini.ai text object and prefix.
---@param opts table mini.ai config (its `mappings` are merged with defaults)
function mini.ai_whichkey(opts)
	local objects = {
		{ " ", desc = "whitespace" },
		{ '"', desc = '" string' },
		{ "'", desc = "' string" },
		{ "(", desc = "() block" },
		{ ")", desc = "() block with ws" },
		{ "<", desc = "<> block" },
		{ ">", desc = "<> block with ws" },
		{ "?", desc = "user prompt" },
		{ "U", desc = "use/call without dot" },
		{ "[", desc = "[] block" },
		{ "]", desc = "[] block with ws" },
		{ "_", desc = "underscore" },
		{ "`", desc = "` string" },
		{ "a", desc = "argument" },
		{ "b", desc = ")]} block" },
		{ "C", desc = "comment" },
		{ "c", desc = "class" },
		{ "d", desc = "digit(s)" },
		{ "e", desc = "CamelCase / snake_case" },
		{ "f", desc = "function" },
		{ "g", desc = "entire file" },
		{ "i", desc = "indent" },
		{ "o", desc = "block, conditional, loop" },
		{ "q", desc = "quote `\"'" },
		{ "r", desc = "return statement" },
		{ "t", desc = "tag" },
		{ "u", desc = "use/call" },
		{ "v", desc = "assignment (i = value)" },
		{ "{", desc = "{} block" },
		{ "}", desc = "{} with ws" },
	}

	-- Textobject prefixes are operator/visual only; the g[ / g] edge motions also work
	-- in normal mode, so they are registered separately.
	local ret = { mode = { "o", "x" } }
	local ret_motion = { mode = { "n", "x", "o" } }
	local mappings = vim.tbl_extend("force", {}, {
		around = "a",
		inside = "i",
		around_next = "an",
		inside_next = "in",
		around_last = "al",
		inside_last = "il",
		goto_left = "g[",
		goto_right = "g]",
	}, opts.mappings or {})

	-- Readable group labels for the popup, keyed by mini.ai mapping name.
	local groups = {
		around = "around",
		inside = "inside",
		around_next = "next",
		inside_next = "next",
		around_last = "last",
		inside_last = "last",
		goto_left = "goto start of",
		goto_right = "goto end of",
	}

	for name, prefix in pairs(mappings) do
		local group = groups[name] or name
		local target = name:find("^goto_") and ret_motion or ret
		target[#target + 1] = { prefix, group = group }
		for _, obj in ipairs(objects) do
			local desc = obj.desc
			if prefix:sub(1, 1) == "i" then
				desc = desc:gsub(" with ws", "")
			end
			target[#target + 1] = { prefix .. obj[1], desc = desc }
		end
	end

	local wk = require("which-key")
	wk.add(ret, { notify = false })
	wk.add(ret_motion, { notify = false })
end

return mini
