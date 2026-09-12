--- snacks.dashboard spec: start screen with quick-action keys and a two-pane layout.
---
--- Nothing here may `require` at spec-eval scope — the dashboard is built during
--- startup, so a require in an `action` field loads that module for every launch,
--- including the ones that open a file and never render this at all.

--- Reads the toolchain store for the status line. Deliberately not
--- `require("toolchain")`: only the JSON is wanted, not the registry behind it.
---@return snacks.dashboard.Item[]
local function toolchain_status()
	local ok, doc = pcall(function()
		return require("toolchain.store").read()
	end)
	if not ok or not doc then
		return {}
	end

	local missing = doc.summary.missing_tools or {}
	if #missing == 0 then
		return {
			{
				icon = " ",
				desc = ("%d tools present"):format(doc.summary.present),
				key = "t",
				action = ":ToolchainDashboard",
			},
		}
	end
	return {
		{
			icon = " ",
			desc = ("%d/%d tools — missing %s"):format(
				doc.summary.present,
				doc.summary.total,
				table.concat(missing, ", ")
			),
			key = "t",
			action = ":ToolchainDashboard",
		},
	}
end

return {
	"folke/snacks.nvim",
	opts = {
		dashboard = {
			--- `parent/name.ext` instead of snacks' width-driven shortening, which turns a
			--- nested path into `~/P/c/q/n/l/t/a/catppuccin.lua` — unreadable, and every
			--- file in a project collapses to the same prefix.
			formats = {
				file = function(item, ctx)
					local path = vim.fn.fnamemodify(item.file, ":~")
					local parent = vim.fn.fnamemodify(path, ":h:t")
					local name = vim.fn.fnamemodify(path, ":t")
					local short = parent ~= "." and parent ~= "~" and (parent .. "/" .. name) or name
					if ctx.width and #short > ctx.width then
						short = name
					end
					local dir, file = short:match("^(.*/)(.+)$")
					return dir and { { dir, hl = "dir" }, { file, hl = "file" } } or { { short, hl = "file" } }
				end,
			},
			preset = {
				header = [[
           ( (
            ) )
         .-------.
        |  ~ ☕ ~ |]
         \_______/
         /\_/\   /
        ( ^.^ ) /
       c(  "  )o
        (__|__)
]],
				---@type fun(cmd:string, opts:table)|nil Picker backend; nil auto-detects fzf-lua/telescope/mini.pick.
				pick = nil,
				---@type snacks.dashboard.Item[] Quick-action entries shown in the `keys` section.
				keys = {
					{ icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
					{ icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
					{ icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
					{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
					{ icon = " ", key = "s", desc = "Restore Session", section = "session" },
					{
						icon = " ",
						key = "c",
						desc = "Config",
						action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
					},
					{
						icon = " ",
						key = "C",
						desc = "Chezmoi",
						-- A string action, so features.chezmoi is not required at startup.
						action = ":lua require('features.chezmoi').pick_chezmoi()",
						-- The picker shells out to chezmoi; without it the entry is dead.
						enabled = vim.fn.executable("chezmoi") == 1,
					},
					{
						icon = "󰸱 ",
						key = "T",
						desc = "Theme",
						-- Leaves the cmdline open on `:Theme ` so <Tab> completes the installed
						-- schemes, rather than running the bare command and only reporting.
						action = function()
							vim.api.nvim_feedkeys(":Theme ", "n", false)
						end,
					},
					{ icon = "󰩺 ", key = "d", desc = "Project Doctor", action = ":ProjectDoctor" },
					{
						icon = "󰒲 ",
						key = "L",
						desc = "Lazy",
						action = ":Lazy",
						enabled = package.loaded.lazy ~= nil,
					},
					{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
				},
			},
			sections = {
				{ section = "header", padding = 1 },
				{ section = "keys", gap = 1, padding = 1 },
				-- Passed as a function, not called: snacks resolves it at render time, so a
				-- launch that opens a file straight away never reads the store at all. The
				-- store is written on idle, so this reflects the last refresh, not now.
				{ icon = " ", title = "Toolchain", indent = 2, padding = 1, toolchain_status },
				{ pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
				{ pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
				{
					pane = 2,
					icon = " ",
					title = "Git Status",
					section = "terminal",
					-- External: Snacks global; only show git status inside a repo.
					enabled = function()
						return Snacks.git.get_root() ~= nil
					end,
					cmd = "git status --short --branch --renames",
					height = 5,
					padding = 1,
					ttl = 5 * 60,
					indent = 3,
				},
				{ section = "startup" },
			},
		},
	},
}
