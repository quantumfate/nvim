local autocmds = {
{
    "VimEnter",
    {
      group = "_general_settings",
      desc = "Disable terminal padding",
      callback = function()
        vim.fn.system(
          "kitty @ set-spacing padding=0 > /dev/null 2>&1"
        )
      end,
    },
  },
  {
    "VimLeave",
    {
      group = "_general_settings",
      desc = "Disable terminal padding",
      callback = function()
        vim.fn.system(
          "kitty @ set-spacing padding-left=15 padding-right=15 padding-top=20 padding-bottom=20 > /dev/null 2>&1"
        )
      end,
    },
  },
}
for _, entry in ipairs(autocmds) do
		local event = entry[1]
    print(event)
		local opts = entry[2]
    print(opts)
		if type(opts.group) == "string" and opts.group ~= "" then
			local exists, _ =
				pcall(vim.api.nvim_get_autocmds, { group = opts.group })
			if not exists then
				vim.api.nvim_create_augroup(opts.group, {})
			end
		end
		vim.api.nvim_create_autocmd(event, opts)
	end