--- trouble.nvim: unified list for diagnostics/quickfix, with []q navigating either.

--- Step through Trouble when it is open, else fall back to the quickfix list.
--- `Snacks` is a global from snacks.nvim, used to surface quickfix errors.
---@param trouble_move "next"|"prev" Trouble navigation method
---@param quickfix_cmd fun() Quickfix fallback command
---@return fun()
local function step(trouble_move, quickfix_cmd)
	return function()
		local trouble = require("trouble")
		if trouble.is_open() then
			trouble[trouble_move]({ skip_groups = true, jump = true })
		else
			local ok, err = pcall(quickfix_cmd)
			if not ok then
				Snacks.notify.error(err)
			end
		end
	end
end

return {
	"folke/trouble.nvim",
	cmd = { "Trouble" },
	opts = {},
	keys = {
		{ "[q", step("prev", vim.cmd.cprev), desc = "Previous Trouble/Quickfix Item" },
		{ "]q", step("next", vim.cmd.cnext), desc = "Next Trouble/Quickfix Item" },
	},
}
