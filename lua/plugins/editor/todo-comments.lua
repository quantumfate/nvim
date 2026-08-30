--- todo-comments.nvim: highlight TODO/FIX/etc. keywords and navigate/search them.
return {
	"folke/todo-comments.nvim",
	event = { "User FileOpened" },
	dependencies = { "nvim-lua/plenary.nvim" },
	opts = {
		highlight = {
			keyword = "wide", -- the marker itself keeps its chip: it IS the signal
			after = "fg", -- and the note after it gets the same hue, dimmed below
		},
	},
	--- The text after `TODO:` is highlighted by the plugin in the FULL keyword
	--- colour at priority 500, which beats treesitter — so a one-line note turns
	--- an entire comment bright sky or red and outshouts the code around it.
	--- Blend those foregrounds halfway into the background instead: the note
	--- still reads as belonging to its marker, but it sits at comment weight.
	--- The chip on the keyword is untouched — that is the part worth spotting.
	---@param opts table todo-comments options
	config = function(_, opts)
		--- Mix two 24-bit colours. `alpha` is the weight of `fg`.
		---@param fg integer
		---@param bg integer
		---@param alpha number
		---@return string hex
		local function blend(fg, bg, alpha)
			local function mix(shift)
				local f, b = math.floor(fg / shift) % 256, math.floor(bg / shift) % 256
				return math.floor(f * alpha + b * (1 - alpha) + 0.5)
			end
			return ("#%02x%02x%02x"):format(mix(65536), mix(256), mix(1))
		end

		--- Re-dims every TodoFg* group. Runs after setup and on every colorscheme
		--- change, because todo-comments rebuilds these groups from its palette.
		--- The group list comes from the highlight namespace rather than the
		--- plugin's config table: `Config.options.keywords` is not populated yet
		--- at this point in setup, and the defined groups are what we act on
		--- anyway — including any keyword added later.
		local function dim_notes()
			local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
			local bg = normal.bg or 0x24273a
			for _, group in ipairs(vim.fn.getcompletion("TodoFg", "highlight")) do
				local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
				if hl.fg then
					vim.api.nvim_set_hl(0, group, { fg = blend(hl.fg, bg, 0.45), italic = true })
				end
			end
		end

		-- Hook the plugin's own colour builder instead of guessing when to run:
		-- it defines the TodoFg*/TodoBg* groups with `hi def` from setup AND from
		-- a deferred ColorScheme handler, and at neither moment do the groups
		-- exist yet when the spec's config runs. Wrapping it means the dim lands
		-- immediately after every definition pass, first one included.
		local config = require("todo-comments.config")
		local colors = config.colors
		config.colors = function(...)
			local result = colors(...)
			dim_notes()
			return result
		end

		require("todo-comments").setup(opts)
	end,
	keys = {
		{
			"]t",
			function()
				require("todo-comments").jump_next()
			end,
			desc = "Next Todo Comment",
		},
		{
			"[t",
			function()
				require("todo-comments").jump_prev()
			end,
			desc = "Previous Todo Comment",
		},
		{
			"<leader>ft",
			-- `Snacks` is a global from snacks.nvim.
			function()
				Snacks.picker.todo_comments()
			end,
			desc = "Todo",
		},
		{
			"<leader>fT",
			function()
				Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } })
			end,
			desc = "Todo/Fix/Fixme",
		},
	},
}
