-- mini.ai spec: extra text objects (functions, classes, tags, digits, buffer, calls) plus which-key hints.

return {
	"nvim-mini/mini.ai",
	event = "User FileOpened",
	--- Builds custom text objects, several backed by treesitter queries.
	---@return table
	opts = function()
		local ai = require("mini.ai")
		return {
			n_lines = 500,
			-- Edge motions follow the layout scheme in config/keymaps.lua:
			-- `-` forward / `_` backward. `g[` and `g]` are kept there as aliases.
			mappings = {
				goto_left = "g_",
				goto_right = "g-",
			},
			custom_textobjects = {
				o = ai.gen_spec.treesitter({ -- code block
					a = { "@block.outer", "@conditional.outer", "@loop.outer" },
					i = { "@block.inner", "@conditional.inner", "@loop.inner" },
				}),
				f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }), -- function
				c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }), -- class
				v = ai.gen_spec.treesitter({ a = "@assignment.outer", i = "@assignment.rhs" }), -- assignment / its value
				r = ai.gen_spec.treesitter({ a = "@return.outer", i = "@return.inner" }), -- return statement
				C = ai.gen_spec.treesitter({ a = "@comment.outer", i = "@comment.inner" }), -- comment
				t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" }, -- tags
				d = { "%f[%d]%d+" }, -- digits
				e = { -- word with case
					{ "%u[%l%d]+%f[^%l%d]", "%f[%S][%l%d]+%f[^%l%d]", "%f[%P][%l%d]+%f[^%l%d]", "^[%l%d]+%f[^%l%d]" },
					"^().*()$",
				},
				g = require("util.plugins.mini").ai_buffer, -- buffer
				u = ai.gen_spec.function_call(), -- function call ("usage")
				U = ai.gen_spec.function_call({ name_pattern = "[%w_]" }), -- call without dotted name
			},
		}
	end,
	--- Applies the spec, then registers which-key hints once which-key loads.
	---@param opts table
	---@return nil
	config = function(_, opts)
		local modules_util = require("util.modules")
		require("mini.ai").setup(opts)
		modules_util.on_load("which-key.nvim", function()
			vim.schedule(function()
				require("util.plugins.mini").ai_whichkey(opts)
			end)
		end)
	end,
}
