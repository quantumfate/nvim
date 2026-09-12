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

--- Reads git status natively without spawning terminal subprocesses that exit with banners.
---@return snacks.dashboard.Item[]
local function git_status()
	local ok, root_dir = pcall(function()
		return Snacks.git.get_root()
	end)
	if not ok or not root_dir then
		return {}
	end

	local res = vim.system({ "git", "status", "--porcelain=v2", "--branch" }, { cwd = root_dir, text = true }):wait()
	if res.code ~= 0 then
		return {}
	end

	local branch = "HEAD"
	local ahead, behind = 0, 0
	local staged, modified, untracked = 0, 0, 0

	for _, line in ipairs(vim.split(res.stdout or "", "\n", { trimempty = true })) do
		if line:match("^# branch%.head ") then
			branch = line:gsub("^# branch%.head ", "")
		elseif line:match("^# branch%.ab ") then
			local a, b = line:match("%+(%d+) %-(%d+)")
			ahead = tonumber(a) or 0
			behind = tonumber(b) or 0
		elseif line:match("^%?") then
			untracked = untracked + 1
		elseif line:match("^[12] ") then
			local xy = line:match("^[12]%s+(%S+)")
			if xy then
				if xy:sub(1, 1) ~= "." then
					staged = staged + 1
				end
				if xy:sub(2, 2) ~= "." then
					modified = modified + 1
				end
			end
		end
	end

	local ab = {}
	if ahead > 0 then
		table.insert(ab, "󰶣 " .. ahead)
	end
	if behind > 0 then
		table.insert(ab, "󰶡 " .. behind)
	end
	local ab_str = #ab > 0 and (" (" .. table.concat(ab, " ") .. ")") or ""

	local items = {
		{
			icon = " ",
			desc = branch .. ab_str,
			key = "g",
			action = ":lua Snacks.picker.git_status()",
			hl = "Special",
		},
	}

	local total = staged + modified + untracked
	if total == 0 then
		table.insert(items, {
			icon = "✔ ",
			desc = "Working tree clean",
			hl = "DiagnosticOk",
		})
	else
		local parts = {}
		if staged > 0 then
			table.insert(parts, staged .. " staged")
		end
		if modified > 0 then
			table.insert(parts, modified .. " modified")
		end
		if untracked > 0 then
			table.insert(parts, untracked .. " untracked")
		end
		table.insert(items, {
			icon = "● ",
			desc = table.concat(parts, " · "),
			hl = modified > 0 and "DiagnosticWarn" or "DiagnosticInfo",
			action = ":lua Snacks.picker.git_status()",
		})
	end

	return items
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
				header = table.concat({
					' _._     _,-\'""`-._    ',
					"(,-.`._,'(       |\\`-/|",
					"    `-.-' \\ )-`( , o o)",
					"          `-    \\`_`\"'-",
				}, "\n"),
				---@type fun(cmd:string, opts:table)|nil Picker backend; nil auto-detects fzf-lua/telescope/mini.pick.
				pick = nil,
				---@type snacks.dashboard.Item[] Quick-action entries shown in the `keys` section.
				keys = {
					{ icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
					{
						icon = " ",
						key = "r",
						desc = "Recent Files",
						action = ":lua Snacks.dashboard.pick('oldfiles')",
					},
					{ icon = "󰩺 ", key = "d", desc = "Project Doctor", action = ":ProjectDoctor" },
					{ icon = "󰏘 ", key = "s", desc = "Project Scaffold", action = ":ProjectScaffold" },
					{ icon = "🧹", key = "S", desc = "Project Sanitize", action = ":ProjectSanitize" },
					{
						icon = "󰸱 ",
						key = "T",
						desc = "Theme Picker",
						action = function()
							vim.api.nvim_feedkeys(":Theme ", "n", false)
						end,
					},
					{ icon = "💥", key = "c", desc = "Crash Dumps", action = ":Crashes" },
					{ icon = " ", key = "x", desc = "Systems Tools", action = ":SysInfo" },
					{ icon = "✉ ", key = "p", desc = "b4 Patch Workflow", action = ":SysPatch" },
				},
			},
			sections = {
				{ section = "header", padding = 1 },
				{ section = "keys", gap = 1, padding = 1 },
				{ pane = 2, icon = " ", title = "Git Status", indent = 2, padding = 1, git_status },
				{ pane = 2, icon = " ", title = "Toolchain", indent = 2, padding = 1, toolchain_status },
				{ pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
				{ pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
				{ section = "startup" },
			},
		},
	},
}
