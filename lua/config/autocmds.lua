local autocmds = {
	{
		"InsertEnter",
		{
			group = "_general_settings",
			desc = "Close nvim tree when entering insert mode",
			callback = function()
				--require("nvim-tree.api").tree.close()
			end,
		},
	},
	{
		"TextYankPost",
		{
			group = "_general_settings",
			pattern = "*",
			desc = "Highlight text on yank",
			callback = function()
				vim.highlight.on_yank({ higroup = "Search", timeout = 100 })
			end,
		},
	},
	{
		"FileType",
		{
			group = "_buffer_mappings",
			pattern = {
				"qf",
				"help",
				"man",
				"floaterm",
				"lspinfo",
				"lir",
				"lsp-installer",
				"null-ls-info",
				"tsplayground",
				"DressingSelect",
				"Jaq",
			},
			callback = function()
				vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true })
				vim.opt_local.buflisted = false
			end,
		},
	},
	-- {
	-- 	"VimEnter",
	-- 	{
	-- 		group = "_general_settings",
	-- 		desc = "Disable terminal padding",
	-- 		callback = function()
	-- 			vim.fn.system("kitty @ --to $KITTY_LISTEN_ON set-spacing padding=0 > /dev/null 2>&1")
	-- 			-- vim.fn.system("kitty @ set-spacing padding=0 > /dev/null 2>&1")
	-- 		end,
	-- 	},
	-- },
	-- {
	-- 	"VimLeave",
	-- 	{
	-- 		group = "_general_settings",
	-- 		desc = "Disable terminal padding",
	-- 		callback = function()
	-- 			vim.fn.system(
	-- 				"kitty @ --to $KITTY_LISTEN_ON set-spacing padding-left=15 padding-right=15 padding-top=20 padding-bottom=20 > /dev/null 2>&1"
	-- 			)
	-- 			-- vim.fn.system(
	-- 			-- 	"kitty @ set-spacing padding-left=15 padding-right=15 padding-top=20 padding-bottom=20 > /dev/null 2>&1"
	-- 			-- )
	-- 		end,
	-- 	},
	-- },
	{ -- taken from AstroNvim
		"BufEnter",
		{
			group = "_dir_opened",
			nested = true,
			callback = function(args)
				local bufname = vim.api.nvim_buf_get_name(args.buf)
				if require("util.fs").is_directory(bufname) then
					vim.api.nvim_del_augroup_by_name("_dir_opened")
					vim.cmd("do User DirOpened")
					vim.api.nvim_exec_autocmds(args.event, { buffer = args.buf, data = args.data })
				end
			end,
		},
	},
	{ -- taken from AstroNvim
		{ "BufRead", "BufWinEnter", "BufNewFile" },
		{
			group = "_file_opened",
			nested = true,
			callback = function(args)
				local buftype = vim.api.nvim_get_option_value("buftype", { buf = args.buf })
				if not (vim.fn.expand("%") == "" or buftype == "nofile") then
					vim.api.nvim_del_augroup_by_name("_file_opened")
					vim.cmd("do User FileOpened")
				end
			end,
		},
	},
}
for _, entry in ipairs(autocmds) do
	local event = entry[1]
	local opts = entry[2]
	if type(opts.group) == "string" and opts.group ~= "" then
		local exists, _ = pcall(vim.api.nvim_get_autocmds, { group = opts.group })
		if not exists then
			vim.api.nvim_create_augroup(opts.group, {})
		end
	end
	vim.api.nvim_create_autocmd(event, opts)
end
