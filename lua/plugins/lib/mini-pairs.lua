-- mini.pairs spec: autopairs with skip rules; setup is delegated to the shared mini util.

return {
	"nvim-mini/mini.pairs",
	event = "User FileOpened",
	opts = {
		modes = { insert = true, command = true, terminal = false },
		skip_next = [=[[%w%%%'%[%"%.%`%$]]=], -- skip autopair when next char matches
		skip_ts = { "string" }, -- skip inside these treesitter nodes
		skip_unbalanced = true, -- skip when closing pairs already outnumber opening ones
		markdown = true, -- handle markdown code blocks
	},
	--- Delegates setup to the shared mini helper.
	---@param opts table
	---@return nil
	config = function(_, opts)
		require("util.plugins.mini").pairs(opts)
	end,
}
